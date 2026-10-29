"""Native-MLX first/last-frame conditioning adapter (under construction)."""
import mlx.core as mx
import mlx.nn as nn
from mlx.utils import tree_flatten

def condition_endpoints(noise,first,last):
    if noise.ndim!=3 or first.ndim!=3 or first.shape!=last.shape or noise.shape[0]!=first.shape[0] or noise.shape[2]!=first.shape[2] or noise.shape[1]<=2*first.shape[1]:
        raise ValueError("Two matching endpoints and interior latent frames are required")
    frame=first.shape[1];middle=noise.shape[1]-2*frame
    latents=mx.concatenate([first,noise[:,frame:-frame,:],last],axis=1)
    mask=mx.concatenate([mx.ones((noise.shape[0],frame)),mx.zeros((noise.shape[0],middle)),mx.ones((noise.shape[0],frame))],axis=1).astype(noise.dtype)
    return latents,mask

def freeze_endpoints(updated,clean,mask):
    return mx.where(mask[:,:,None]>0,clean,updated)

def stream_quantized_load(model,weights):
    """Consume native parameter tensors one by one, retaining only compact weights."""
    expected={name for name,_ in tree_flatten(model.parameters())}
    if set(weights)!=expected:
        raise ValueError(f"Checkpoint parameters differ: missing {sorted(expected-set(weights))[:4]}, unexpected {sorted(set(weights)-expected)[:4]}")
    paths={name for name,module in model.named_modules() if isinstance(module,nn.Linear) and module.weight.shape[1]%64==0}
    nn.quantize(model,group_size=64,bits=4,class_predicate=lambda path,module:path in paths)
    compact={}
    for name in list(weights):
        value=weights.pop(name)
        if name.endswith('.weight') and name[:-7] in paths:
            q,scales,biases=mx.quantize(value.astype(mx.bfloat16),group_size=64,bits=4)
            mx.eval(q,scales,biases)
            compact[name]=q;compact[name[:-7]+'.scales']=scales;compact[name[:-7]+'.biases']=biases
        else:
            converted=value.astype(mx.bfloat16) if mx.issubdtype(value.dtype,mx.floating) else value
            mx.eval(converted);compact[name]=converted
        del value
        mx.clear_cache()
    model.load_weights(list(compact.items()),strict=True)
    mx.eval(model.parameters())
    return model


def t5_relative_position_bucket(relative_position,num_buckets=32,max_distance=128):
    """T5 bidirectional distance bins, retaining its trained 128-token range."""
    import math
    half=num_buckets//2;exact=half//2
    distance=mx.abs(relative_position)
    far=exact+(mx.log(mx.maximum(distance,exact).astype(mx.float32)/exact)/math.log(max_distance/exact)*(half-exact)).astype(mx.int32)
    return (relative_position>0).astype(mx.int32)*half+mx.where(distance<exact,distance,mx.minimum(far,half-1))
