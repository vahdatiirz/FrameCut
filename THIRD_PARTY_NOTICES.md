# Third-party components

The root MIT license covers original FrameCut code. It does not replace the licenses for the following components:

| Component | Origin | License / notice |
|---|---|---|
| WhisperKit / Argmax OSS Swift, pinned 1.1.1 | https://github.com/argmaxinc/argmax-oss-swift | `App/Licenses/Argmax-MIT.txt`, `Argmax-Third-Party-Notices.txt`; resolved dependencies retain their own notices |
| Multilingual Whisper Tiny Core ML model | https://huggingface.co/argmaxinc/whisperkit-coreml | MIT, `App/Licenses/OpenAI-Whisper-MIT.txt` and Argmax notices |
| Whisper Tiny tokenizer | https://huggingface.co/openai/whisper-tiny | Apache-2.0, `App/Licenses/OpenAI-Tokenizer-Apache-2.0.txt` |

Exact model source revisions, sizes and SHA-256 values are in `App/Models/WhisperTiny/manifest.json`. Origin information is also included in the app's About screen. No VN executable, framework, premium template or catalog artwork is redistributed. Apple frameworks remain governed by Apple's terms.


## Optional Mac video companion

The companion adapter source is included, but video foundation-model weights and the ltx-mlx runtime checkout are not. MLX/Python packages must be installed separately. LTX model files, the external quantized T5 component and runtime have their own terms/provenance; see Companion/README.md. The app's MIT license does not license those external assets, and their redistribution has not been cleared by this release. No paid VN backend, credentials or assets are included.
