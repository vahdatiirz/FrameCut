<p align="center"><img src="App/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="112" alt="FrameCut icon"></p>

# FrameCut

**A free, independent video editor for iPhone and iPad, inspired by the workflow of VN Video Editor.**

[Download 0.9.0 preview](https://github.com/vahdatiirz/FrameCut/releases/tag/v0.9.0) · [Installation](Docs/INSTALL.md) · [فارسی](README.fa.md) · [Feature coverage](Docs/FEATURE-COVERAGE.md) · [Report a bug](https://github.com/vahdatiirz/FrameCut/issues)

**Experimental preview — 0.9.0, build 14.** FrameCut is not a complete VN replacement or an official VN app. Original implementations and synthetic samples are provided; VN code, paid templates and cloud access are not included.

## Install

| Destination | Installation route |
|---|---|
| iPhone or iPad | Download the source, open it in Xcode on a Mac, choose your own signing team and run on your device. |
| Apple Silicon Mac / iOS Simulator | Build from source, or use the clearly labeled simulator archive from this release. |
| Direct one-tap iPad installation | Not available. There is no public TestFlight/App Store release or universally installable IPA. A simulator app cannot run on a physical iPad. |

The source and simulator package are free. Apple signing requirements still apply. [English / Persian instructions](Docs/INSTALL.md).

## What it does

- **Edit a film:** import video/photos from Photos or Files; trim, split, reorder, duplicate, replace, rotate, mirror, fit/fill, save drafts and undo/redo. Fit the whole timeline or zoom to 30×; captions, audio and layers have separate rows.
- **Transitions:** **32 local styles** across Basic, Motion, Matte and Effects. Tap the persistent **+ between clips**, preview both clips, set duration, apply to all or remove. The new **Smoke Drift, Confetti and Gold Confetti** are independent local visual effects. Smoke currently looks like textured mist; cinematic realism and equivalence to VN are not claimed. [New examples](Docs/Atmosphere-0.9.jpg).
- **Speed and clip tools:** 0.1×–100× speed, editable curves with six recipes, silent SDR reverse, freeze frames and PNG extraction.
- **Layers and motion:** timed video/photo/transparent-PNG overlays, position, size, rotation, opacity, masks and motion keyframes; **19 original motion recipes**.
- **Looks and FX:** **30 look choices including Original**, Before/After preview, **12 timed video FX**, intensity/color controls, 3D `.cube` LUT import, shape/polygon masks, regional blur and mosaic.
- **Creative starting points:** **12 original editing recipes** and a separate editable sample film.
- **Text and sound:** timed titles/captions, SRT import/export, project-local TTF/OTF fonts, independent audio regions, volume/fades and audio extraction.
- **Offline speech:** bundled multilingual Whisper Tiny captions with word timings; narration with voices available on the device. These implemented paths need no paid API key.
- **Export:** unwatermarked SDR MP4, 720p/1080p/4K, 24/25/30/50/60 fps and bitrate choices. Higher FPS can repeat frames; optical-flow interpolation is not implemented.
- **Guidance:** task-based help with English/Persian search keywords. The interface is mostly English; full Persian localization is incomplete.

### Optional experimental Mac generation

The AI bridge prepares two endpoint images and a prompt for a separate Mac companion, then imports an externally rendered MP4 into the overlap. It does **not** run a foundation video model on the iPad. The 17 prompt choices are experimental intentions, not 17 completed VN premium effects. Initial LTX 2B trials failed the requested smoke appearance. External video-model weights/runtime are not bundled. See [Companion instructions and limits](Companion/README.md).

## Verification

**72 core tests passed. Nine synthetic checks passed on a physical iPad Pro 11-inch M4 with iPadOS 26.5.2**, including all 32 local renderers; each new effect exported as a 4.6-second 720p30 film and all 138 frames per film decoded; offline captions/speech, an edited movie and a short 4K60 export also passed. Three existing draft JSON files were unchanged across installation/testing. A fractional-overlap rounding defect was fixed and has an export regression check.

These are bounded tests. They do not establish zero bugs, complete manual UI coverage, real-time performance on every device or full VN parity. [Details and remaining limits](Docs/VERIFICATION.md).

## Build

- iOS/iPadOS 18+; core package macOS 15+. Older supported OS versions remain unverified.
- Verified development toolchain: Xcode 26.6, Apple Silicon simulator with iOS 26.5.
- Xcode resolves pinned WhisperKit 1.1.1. Approximately 81 MB of speech-model/tokenizer assets are bundled and content-hash checked; automatic runtime speech-model download is disabled.

```sh
git clone https://github.com/vahdatiirz/FrameCut.git
cd FrameCut
open FrameCut.xcodeproj
```

Select the FrameCut scheme and a simulator, or configure your own device signing. Core checks: `swift test`.

## License and credits

Original FrameCut code is [MIT licensed](LICENSE). Model/runtime/dependency licenses remain separate; see [third-party notices](THIRD_PARTY_NOTICES.md) and `App/Licenses`. VN is named only to explain inspiration and comparison. For issues, provide reproducible steps and non-private sample media; do not upload credentials or device identifiers.
