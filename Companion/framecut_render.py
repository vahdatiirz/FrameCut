"""Local LTX-Video inference with staged, bounded Apple-Silicon loading.

Uses pretrained Lightricks weights and the pinned ltx-mlx model implementation.
This module does not train a foundation model or call a cloud generator.
"""
import base64,gc,hashlib,io,json,time
from pathlib import Path
from framecut_generation import validate_job,validate_local_profile

MODEL_REVISION='8984fa25007f376c1a299016d0957a37a2f797bb'
MODEL_SHA256='76aa8c4786af752fa6f951947129d5290c3c6c0b2fadcadea6b5e114ae2cad8f'
TEXT_SHAS={'0.safetensors':'49e139f50824fef40908ef4307c851e7adaa8b91bed44054c4829600dbedfdda','1.safetensors':'086e76e71dd5b1baef0fd07d3410adee44f52fa51627778e1f025a2d75e31139'}


def verify_file(path,wanted):
    h=hashlib.sha256()
    with Path(path).open('rb') as source:
        for chunk in iter(lambda:source.read(4*1024*1024),b''):h.update(chunk)
    if h.hexdigest()!=wanted:raise ValueError('Model file hash mismatch: '+Path(path).name)


def text_key(key):
    if not key.startswith('t5_blocks.'):return key
    parts=key.split('.');index,group=parts[1],parts[2];rest='.'.join(parts[3:])
    if 'relative_attention_bias.' in rest:return 'pos_bias.embedding.'+rest.rsplit('.',1)[1]
    if group not in ('attention','ff'):raise ValueError('Unsupported text encoder key')
    return f'blocks.{index}.layer_{0 if group=="attention" else 1}_{rest}'


def transformer_key(key):
    key=key.removeprefix('model.diffusion_model.')
    for old,new in [('patchify_proj.','proj_in.'),('adaln_single.emb.timestep_embedder.linear_1.','time_embed.timestep_embedder_linear_1.'),('adaln_single.emb.timestep_embedder.linear_2.','time_embed.timestep_embedder_linear_2.'),('adaln_single.linear.','time_embed.linear.'),('transformer_blocks.','blocks.'),('.q_norm.','.norm_q.'),('.k_norm.','.norm_k.'),('.to_out.0.','.to_out.'),('.ff.net.0.proj.','.ff.proj_in.'),('.ff.net.2.','.ff.proj_out.')]:
        key=key.replace(old,new)
    return key


def render_job(job,model_dir,text_model_dir,runtime_root,output_dir):
    import sys
    runtime_root=Path(runtime_root).resolve();sys.path.insert(0,str(runtime_root))
    import mlx.core as mx
    import mlx.nn as nn
    import numpy as np
    import imageio.v2 as imageio
    from PIL import Image
    from ltx_mlx.models.text_encoder import T5Encoder,T5Tokenizer,T5RelativePositionBias
    from ltx_mlx.models.transformer import LTXVideoTransformer,compute_rope
    from ltx_mlx.models.vae import load_vae_encoder,load_vae_decoder
    from ltx_mlx.scheduler import euler_step
    from framecut_mlx import condition_endpoints,freeze_endpoints,stream_quantized_load,t5_relative_position_bucket
    job=validate_job(job)
    validate_local_profile(job)
    model_dir,text_model_dir=Path(model_dir),Path(text_model_dir)
    checkpoint=model_dir/'ltxv-2b-0.9.8-distilled.safetensors'
    started=time.monotonic();output_dir=Path(output_dir).resolve();output_dir.mkdir(parents=True,exist_ok=True)
    mx.set_memory_limit(4*1024**3);mx.set_cache_limit(64*1024**2)
    def phase(name):
        gc.collect();mx.clear_cache()
        print(json.dumps({'phase':name,'elapsedSeconds':round(time.monotonic()-started,2),'activeGB':round(mx.get_active_memory()/1e9,3)}),flush=True)
    phase('Verify immutable weights')
    verify_file(checkpoint,MODEL_SHA256)
    for name,digest in TEXT_SHAS.items():verify_file(text_model_dir/name,digest)
    tokenizer=T5Tokenizer(str(model_dir/'tokenizer/spiece.model'),max_length=128)
    if len(tokenizer.sp.Encode(job['prompt']))>127:raise ValueError('Prompt is too long for this local profile; shorten it to fewer than 128 tokens')
    config=json.loads((model_dir/'text_encoder/config.json').read_text())
    phase('Load 4-bit text encoder')
    t5=T5Encoder(vocab_size=config['vocab_size'],dim=config['d_model'],num_heads=config['num_heads'],head_dim=config['d_kv'],dim_ff=config['d_ff'],num_layers=config['num_layers'])
    class TrainedRangePositionBias(T5RelativePositionBias):
        _bucket=staticmethod(t5_relative_position_bucket)
    t5.pos_bias=TrainedRangePositionBias(config.get("relative_attention_num_buckets",32),config["num_heads"])
    nn.quantize(t5,group_size=64,bits=4)
    text_weights={}
    for path in sorted(text_model_dir.glob('*.safetensors')):
        for key,value in mx.load(str(path)).items():
            text_weights[text_key(key)]=value.astype(mx.bfloat16) if mx.issubdtype(value.dtype,mx.floating) else value
    t5.load_weights(list(text_weights.items()),strict=True);del text_weights
    ids,attention_mask=tokenizer.encode(job['prompt'])
    embeddings=t5(ids,mask=attention_mask);mx.eval(embeddings)
    if not mx.all(mx.isfinite(embeddings)).item():raise ValueError('Nonfinite text embeddings')
    embeddings=mx.array(np.array(embeddings.astype(mx.float32))).astype(mx.bfloat16);mx.eval(embeddings)
    del t5;phase('Text encoded; release text model')
    first=np.array(Image.open(io.BytesIO(base64.b64decode(job['firstFramePNG']))).convert('RGB'))
    last=np.array(Image.open(io.BytesIO(base64.b64decode(job['lastFramePNG']))).convert('RGB'))
    raw=mx.load(str(checkpoint));mean=raw['vae.per_channel_statistics.mean-of-means'].astype(mx.bfloat16);std=raw['vae.per_channel_statistics.std-of-means'].astype(mx.bfloat16)
    mx.eval(mean,std);del raw
    h,w,n=job['height'],job['width'],job['numFrames'];lh,lw,lt=h//32,w//32,(n-1)//8+1
    encoder=load_vae_encoder(str(checkpoint),mx.bfloat16)
    def encode(image):
        values=mx.array((image.astype(np.float32)/127.5-1)[None,None,...]).astype(mx.bfloat16)
        latent=encoder(values);mx.eval(latent)
        latent=((latent-mean[None,None,None,None,:])/std[None,None,None,None,:]).reshape(1,lh*lw,128)
        return mx.array(np.array(latent.astype(mx.float32))).astype(mx.bfloat16)
    a,b=encode(first),encode(last);mx.eval(a,b);del encoder;phase('Endpoints encoded; release image encoder')
    raw=mx.load(str(checkpoint));prefix='model.diffusion_model.'
    inner=raw[prefix+'patchify_proj.weight'].shape[0]
    block_count=1+max(int(k.split('transformer_blocks.')[1].split('.')[0]) for k in raw if 'transformer_blocks.' in k)
    if inner!=2048 or block_count!=28:raise ValueError('This bounded runtime supports only the pinned 2B checkpoint')
    transformer=LTXVideoTransformer(inner_dim=inner,num_heads=32,head_dim=64,num_layers=block_count,cross_dim=inner,caption_channels=4096)
    parameters={transformer_key(key):raw.pop(key) for key in list(raw) if key.startswith(prefix) and '.to_out.1.' not in key}
    del raw
    # Upstream PyTorch has non-affine RMS norms here; MLX represents them with unit weights.
    for index in range(block_count):
        for name in ('norm1','norm2'):
            parameters[f'blocks.{index}.{name}.weight']=mx.ones((inner,),dtype=mx.bfloat16)
    phase('Quantize transformer one tensor at a time')
    transformer=stream_quantized_load(transformer,parameters);del parameters
    seq=lt*lh*lw
    rope=compute_rope(seq,inner,lt,lh,lw,rope_interpolation_scale=(8/job['framesPerSecond'],32,32))
    mx.random.seed(job['seed']);noise=mx.random.normal((1,seq,128)).astype(mx.bfloat16)
    clean,mask=condition_endpoints(noise,a,b);latents=clean
    sigmas=[1.0,0.993,0.987,0.981,0.975,0.909,0.725,0.00003,0.0]
    phase('Neural diffusion')
    for index,(current,next_sigma) in enumerate(zip(sigmas,sigmas[1:])):
        prediction=transformer(latents,mx.array([current*1000]),embeddings,lt,lh,lw,rope=rope,encoder_attention_mask=attention_mask,conditioning_mask=mask)
        latents=freeze_endpoints(euler_step(prediction,current,next_sigma,latents),clean,mask)
        if not mx.all(mx.isfinite(latents)).item():raise ValueError(f'Nonfinite diffusion at step {index+1}')
        mx.eval(latents)
        print(json.dumps({'diffusionStep':index+1,'steps':8,'elapsedSeconds':round(time.monotonic()-started,2)}),flush=True)
    latents=mx.array(np.array(latents.astype(mx.float32))).astype(mx.bfloat16);mx.eval(latents)
    del transformer,prediction,clean,noise,rope;phase('Release transformer; decode video')
    decoder=load_vae_decoder(str(checkpoint),mx.bfloat16)
    denormalized=(latents*std[None,None,:]+mean[None,None,:]).reshape(1,lt,lh,lw,128)
    video=decoder(denormalized,temb=mx.array([0.05]).astype(mx.bfloat16));mx.eval(video)
    decoded=np.array(video.astype(mx.float32))[0]
    if decoded.shape!=(n,h,w,3) or not np.isfinite(decoded).all():raise ValueError(f'Invalid neural decode: shape={decoded.shape}, expected={(n,h,w,3)}, finite={np.isfinite(decoded).all()}, range={np.nanmin(decoded)}..{np.nanmax(decoded)}')
    frames=(np.clip((decoded.astype(np.float32)+1)/2,0,1)*255).astype(np.uint8)
    if frames[1:-1].std()<5:raise ValueError('Neural output is blank or collapsed')
    del decoder,video,decoded,latents,denormalized;phase('Encode neural and endpoint-anchored movies')
    stem='FrameCut-'+job['jobID'];raw_movie=output_dir/(stem+'-raw.mp4');movie=output_dir/(stem+'.mp4')
    imageio.mimwrite(raw_movie,frames,fps=24,codec='libx264',quality=9,macro_block_size=1)
    anchored=frames.copy()
    for i in range(2):
        weight=1-i/2
        anchored[i]=np.clip(first.astype(float)*weight+frames[i]*(1-weight),0,255).astype(np.uint8)
        anchored[-1-i]=np.clip(last.astype(float)*weight+frames[-1-i]*(1-weight),0,255).astype(np.uint8)
    imageio.mimwrite(movie,anchored,fps=24,codec='libx264',quality=9,macro_block_size=1)
    result={'status':'rendered','jobID':job['jobID'],'preset':job['preset'],'model':'Lightricks/LTX-Video 2B distilled 0.9.8','modelRevision':MODEL_REVISION,'modelSHA256':MODEL_SHA256,'quantization':'MLX affine 4-bit transformer/text, bfloat16 VAE','diffusionSteps':8,'width':w,'height':h,'numFrames':n,'fps':24,'elapsedSeconds':round(time.monotonic()-started,2),'peakModelMemoryGB':round(mx.get_peak_memory()/1e9,3),'movie':str(movie),'rawMovie':str(raw_movie),'sha256':hashlib.sha256(movie.read_bytes()).hexdigest(),'endpointAnchoringFrames':2,'qualityApproval':'pending visual review'}
    (output_dir/(stem+'-result.json')).write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result),flush=True);return result


def main():
    import argparse
    parser=argparse.ArgumentParser(description='Render a FrameCut endpoint job locally on Apple Silicon')
    for name in ['job','model-dir','text-model-dir','runtime-root','output-dir']:parser.add_argument('--'+name,required=True)
    args=parser.parse_args();path=Path(args.job)
    if path.stat().st_size>9_000_000:raise ValueError('Job file too large')
    job=validate_job(json.loads(path.read_text()))
    render_job(job,args.model_dir,args.text_model_dir,args.runtime_root,args.output_dir)

if __name__=='__main__':main()
