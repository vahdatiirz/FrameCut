# FrameCut 0.9.0 — Experimental Preview

Free, independent iPhone/iPad editor inspired by VN's editing workflow. Not a complete VN replacement.

## New since the public 0.5 preview

- 32 local transitions with a persistent + between clips, live preview, duration, removal/apply-all, and Basic/Motion/Matte/Effects categories.
- Initial Smoke Drift, Confetti and Gold Confetti. Smoke remains textured mist; further realism is deferred. These are independent visual effects, not VN cloud AI.
- 30 look choices, 12 timed FX, separate editable sample film, Files access and whole-timeline fit improvements.
- Optional experimental Mac AI bridge; external model weights/runtime are not bundled. Its 17 prompt options are not 17 verified premium effects.
- Fixed fractional-overlap video-composition timing that could reject exports.

## Validation

72 core tests passed. Nine checks passed on a physical iPad M4, including all 32 renderers, all 138 decoded frames of each new effect's 720p30 export, offline speech, edited-film export and a short 4K60 export. Three pre-existing draft files stayed unchanged. These checks do not prove zero bugs or full VN parity.

## Installation

- **FrameCut-0.9.0-Source.zip:** build in Xcode on a Mac with your own signing team for iPhone/iPad.
- **FrameCut-0.9.0-Simulator-arm64.zip:** Apple Silicon iOS Simulator app only, not an iPad installer.
- **INSTALL.md:** English/Persian installation instructions.
- **SHA256SUMS.txt:** archive integrity checks.

No public TestFlight/App Store or universal IPA is provided. No developer-signed physical-device build is distributed. See repository Docs/VERIFICATION.md and Docs/FEATURE-COVERAGE.md for limits.

## فارسی

نسخهٔ آزمایشی ۰٫۹٫۰، بیلد ۱۴: ۳۲ ترنزیشن محلی، سه افکت اولیهٔ دود/کاغذرنگی/طلایی و اصلاح خطای خروجی. ۷۲ آزمون هسته و ۹ بررسی روی آیپد واقعی موفق شدند. ظاهر فعلی دود برای این آپدیت پذیرفته شده و بهبود آن به نسخهٔ بعد موکول است؛ برابری کامل با VN ادعا نمی‌شود. برای نصب روی آیپد، سورس را با تیم امضای خودتان در Xcode بسازید؛ بستهٔ Simulator روی آیپد واقعی نصب نمی‌شود.
