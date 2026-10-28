# Verification boundaries

The original 0.5.0 (6) development build passed 50 core tests, zero failures, exit 0, and five physical-iPad smoke checks on iPadOS 26.5.2:

1. Separate synthetic fixtures, without editing personal projects.
2. Local English transcription with bundled Whisper Tiny and word timestamps.
3. Device speech synthesis, then offline recognition of its words.
4. 720p30 output with audio, captions, motion, overlay, transition and persisted project.
5. 3840×2160 at 60fps, exactly 30 decoded frames in 0.5 seconds.

The public source is copied from that implementation, with new publication documentation and no editing behavior changes. Fresh public-package checks are recorded in `verification.json`. Original local logs, device identifiers, provisioning data and private development paths are intentionally not published.

GUI observations: direct guide opening, guide-to-layers routing, 19 motion menu entries, Pop in draft scale and quality settings before rendering. This does not verify saving from every nested toolbar or rendering all motion presets.

Not verified: complete VN parity, every OS/device/voice/language, direct timeline gestures on all devices, long projects, full accessibility, HDR and any public TestFlight/device installer. There is no guarantee of zero bugs. See the feature coverage table before relying on a feature.
