# FrameCut local generation companion — experimental, optional

The iPad prepares two endpoint PNGs and a prompt in a JSON file. This **Mac-only** runner performs real neural generation using pretrained Lightricks LTX-Video weights. Import the resulting MP4 in the same transition editor, preview it, and use Apply to commit. It occupies the existing overlap and does not shift captions, audio or later clips. It is not a new foundation model, an embedded iPad generator, or VN's backend.

## Current quality boundary

Two real M2/8 GB runs passed decode/endpoint tests (25 and 49 frames). Both failed the requested smoke appearance on the Dawn/Dusk illustration and distorted its baked-in lettering. Therefore **Smoke Drift is not accepted** and the 17 prompt presets are not 17 completed effects. Neither output establishes coherent 3D motion, subject tracking, or parity with VN. Review the raw movie as well as the endpoint-anchored movie. The latter explicitly blends two frames at each end; this does not improve the interior model's prompt adherence.

## Tested environment and immutable dependencies

- Native Apple Silicon Python 3.12. Dependencies in `requirements.txt`.
- Runtime: https://github.com/baisampayans/ltx-mlx at `0d884df6c5f086915e4ffdab950d914757c306f2`. Read the source and its licensing before using or redistributing it. The runner imports its model classes; it does not use the upstream all-models-at-once pipeline.
- Main checkpoint: https://huggingface.co/Lightricks/LTX-Video at `8984fa25007f376c1a299016d0957a37a2f797bb`, file `ltxv-2b-0.9.8-distilled.safetensors`, SHA256 `76aa8c4786af752fa6f951947129d5290c3c6c0b2fadcadea6b5e114ae2cad8f`.
- Also obtain `text_encoder/config.json` and `tokenizer/spiece.model` from that exact LTX revision.
- Quantized **T5 component only**: https://huggingface.co/mlx-community/Flux-1.lite-8B-MLX-Q4 at `3e346b4b6df4c142d07553d93136ba9ec4ffb578`, `text_encoder_2/0.safetensors` and `text_encoder_2/1.safetensors`. File digests are checked by the runner. Flux image-generation weights are not used.
- About 9 GB of weights are required. Model download, runtime setup and license/provenance review are not yet packaged as a consumer installer. **Weights and third-party runtime are not bundled or publicly redistributed.** The model card labels the model license `other`; do not apply the app's license to these assets.

Install requirements in a separate Python environment. Arrange the main checkpoint plus `text_encoder/` and `tokenizer/` inside MODEL_DIR, and the two T5 files directly inside TEXT_MODEL_DIR. RUNTIME_ROOT is the reviewed runtime checkout.

```sh
python framecut_render.py --job REQUEST.json --model-dir MODEL_DIR --text-model-dir TEXT_MODEL_DIR --runtime-root RUNTIME_ROOT --output-dir RENDERS
```

Output contains a raw MP4, an endpoint-anchored MP4 and a result JSON with model revision/hash, seed, dimensions, timing, peak MLX memory and movie hash. The runner makes no cloud requests. It fails on hash mismatch, incompatible model, nonfinite values or blank output; it never silently substitutes a dissolve for neural generation.

Bfloat16 is necessary for numerical range; the initial float16 implementation produced NaNs and was rejected. Model stages are released between text encoding, image encoding, quantized diffusion and video decoding. The allocator's configured 4 GiB memory limit is **not a hard process-memory guarantee**: observed peak MLX allocation was 6.29 GB for 512×288/25 frames and 6.77 GB for 384×224/49 frames. Running simulators concurrently caused substantial slowdown. A preflight rejects more than 4.3 million pixel-frames before loading weights. This bounds decoder work; it is not a guaranteed RAM ceiling. Longer/higher-resolution jobs, other Macs, all presets and iPad generation remain unverified. Avoid assuming every schema-valid resolution is feasible on an 8 GB Mac.

Tests: `python -m unittest discover -s tests -v`. The real-model test is explicitly skipped unless FRAMECUT_TEST_JOB, FRAMECUT_MODEL_DIR, FRAMECUT_TEXT_MODEL_DIR, FRAMECUT_RUNTIME_ROOT and FRAMECUT_TEST_OUTPUT are configured. A skipped model test does not establish inference success.
