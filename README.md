<p align="center"><img src="App/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="112" alt="FrameCut icon"></p>

# FrameCut

**An independent, offline-first video editor for iPhone and iPad, inspired by the editing workflow of VN Video Editor.**

**ویرایشگر مستقل ویدئو برای آیفون و آیپد، با الهام از گردش کار VN Video Editor**

[Download 0.5.0](https://github.com/vahdatiirz/FrameCut/releases/tag/v0.5.0) · [Install / نصب](Docs/INSTALL.md) · [فارسی](README.fa.md) · [Feature coverage](Docs/FEATURE-COVERAGE.md) · [Report a bug](https://github.com/vahdatiirz/FrameCut/issues)

> **Experimental preview — version 0.5.0, build 6.** FrameCut implements a growing set of editing tools; it is not a complete VN replacement. It is not affiliated with, endorsed by, or an official version of VN. No VN code, paid templates, catalog assets or subscription access are included.

## Install

| What you want | Available route |
|---|---|
| Run on your iPhone or iPad | Download the source, open the Xcode project on a Mac, select your own signing team and run on your device. |
| Try without a physical device | Build for an iOS Simulator on a Mac with Xcode. See the release for any available Apple Silicon simulator package. |
| Tap a link on iPad and install | **Not available yet.** There is no public TestFlight/App Store release or universally installable IPA. A simulator `.app` cannot run on an iPad. |

The source and simulator package are free to download. Apple signing and distribution rules still apply. Full instructions: **[English / فارسی installation guide](Docs/INSTALL.md)**.

## Features implemented

- **Timeline editing:** import photos and videos, trim, split, reorder, duplicate, replace, rotate, mirror, fit/fill, save projects and undo/redo. Timeline zoom up to 30×, source poster thumbnails and separate rows for overlapping captions, audio and overlays.
- **Speed and clip tools:** constant speed from 0.1× to 100×, editable speed curves with six recipes, silent SDR reverse, freeze frames and PNG frame extraction.
- **Layers and motion:** timed video/photo/transparent-PNG overlays, position, scale, rotation, opacity, masks and editable motion keyframes with easing; **19 original motion recipes**.
- **Transitions:** two playing sources blended with dissolve, left/right wipe or left/right slide; separate black/white clip fades.
- **Creative tools:** **12 original editing recipes**, nine looks plus Original, intensity and color adjustments, 3D `.cube` LUT import, shape/polygon masks, feather/inversion, regional blur and square/hexagonal mosaic.
- **Text:** timed multiline titles/captions, UTF-8 SRT import/export and project-local TTF/OTF font import.
- **Offline speech:** bundled multilingual **Whisper Tiny** for captions with word timestamps; text-to-speech using voices available on the device. No paid API key or cloud subscription is required for these implemented paths.
- **Audio:** independent audio regions, source trim, placement, level and fade in/out, plus audio extraction from video.
- **Export:** unwatermarked SDR MP4 at 720p, 1080p or 4K; 24/25/30/50/60 fps and bitrate choices. Increasing output FPS may repeat source frames; it is not optical-flow interpolation.
- **Getting started:** a task-based Tools & help panel with searchable English/Persian keywords. The full interface is currently mostly English; complete Persian localization is not claimed.

A new editor can follow **import → arrange → add text/audio → preview → export**. The top Export button opens quality settings before rendering.

## Verification and limits

The development build passed **50 core tests** and **five physical-iPad smoke checks**, including offline English captions, local speech synthesis, a 720p30 edited movie and a 4K60 export with 30 decoded frames in half a second. These are bounded checks, not proof of all-device compatibility or an absence of bugs. See [verification details](Docs/VERIFICATION.md).

Still incomplete or unverified: full VN catalog/parity, HDR, HSL animation, stabilization, background cutout, frame interpolation, beat detection/AutoCut, recording, full photo/collage tools, portable protected projects, generated avatars/video, long-film reliability, all language accuracy and complete accessibility. Direct timeline gestures, all 19 rendered motion recipes and mixed-language search entry need broader device testing. Back up important media and use copies while trying this preview.

## Build and contribute

- Deployment target: iOS/iPadOS **18+**. Core package: macOS **15+**.
- Development environment verified with **Xcode 26.6**, iPadOS **26.5.2** and an Apple Silicon iOS Simulator. Older supported OS versions and Intel simulators have not been verified.
- Open `FrameCut.xcodeproj`, select scheme **FrameCut**, and choose a simulator or configure your own device signing.
- Xcode resolves **WhisperKit 1.1.1**. Approximately 81 MB of model/tokenizer assets are bundled and pinned by content hashes; runtime model download is disabled.

```sh
git clone https://github.com/vahdatiirz/FrameCut.git
cd FrameCut
open FrameCut.xcodeproj
```

Core checks on a compatible Mac:

```sh
swift test
```

Please report a reproducible case, device/OS, expected result and actual result in [Issues](https://github.com/vahdatiirz/FrameCut/issues). Do not post private media, credentials or device identifiers. See [architecture](Docs/ARCHITECTURE.md).

## License and credits

Original FrameCut source is [MIT licensed](LICENSE). Bundled model/tokenizer and dependency licenses remain separate; see [third-party notices](THIRD_PARTY_NOTICES.md) and `App/Licenses`. The name VN is used only to explain the inspiration and comparison, not to imply affiliation. Samples are synthetic development media.
