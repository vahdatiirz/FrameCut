# Install FrameCut 0.9.0

[فارسی](#نصب-فارسی)

FrameCut is an experimental native iPhone/iPad app. There is currently **no public TestFlight, App Store listing or universal IPA**. GitHub hosts the source and any explicitly labeled simulator package, not a one-tap iPad installer.

## iPhone or iPad — build with Xcode

1. Use a Mac with Xcode. Development was verified with Xcode 26.6. The app's deployment target is iOS/iPadOS 18+, but older OS versions have not yet been tested.
2. Download `FrameCut-0.9.0-Source.zip` from the [release](https://github.com/vahdatiirz/FrameCut/releases/tag/v0.9.0), extract it, and open `FrameCut.xcodeproj` inside its folder. Alternatively clone the repository.
3. Allow Xcode to resolve the pinned Swift package dependency. Internet is needed for this first build; the speech model is already included in the source package.
4. Select the **FrameCut** target → **Signing & Capabilities**. Enable automatic signing, select **your own team**, and use a unique bundle identifier, such as `com.yourname.framecut`.
5. Connect and unlock your device. Pair/trust it using Xcode's normal device flow. If iOS asks for Developer Mode or developer trust, follow Apple's on-device instructions yourself.
6. Select scheme **FrameCut** and your connected device, then choose **Product → Run**.

Apple permits personal-device testing using a Personal Team, with limits and provisioning that expires after seven days; rebuild/reinstall as required. Program memberships and distribution options differ. See [Apple account documentation](https://developer.apple.com/help/account/basics/about-your-developer-account/).

The developer-signed copy installed on the original test device is not a public installer and is not distributed in this release. Your signing identity and provisioning profile must be appropriate for your device.

## Mac — iOS Simulator

FrameCut does not currently provide a native macOS desktop app.

### Build from source

Open `FrameCut.xcodeproj`, choose **FrameCut** and an installed iPhone/iPad simulator, then run. This is the preferred route for different simulator runtimes.

### Prebuilt Apple Silicon simulator package

If the release includes `FrameCut-0.9.0-Simulator-arm64.zip`, it contains an iOS **Simulator** `.app`, built with the iOS 26.5 SDK and tested with the iOS 26.5 runtime on Apple Silicon. It is not an iPhone/iPad device app and not an Intel simulator package.

1. Install Xcode and its matching iOS 26.5 simulator runtime, and boot one iPhone or iPad simulator in Xcode/Simulator.
2. Extract the zip. With only the intended simulator booted, drag `FrameCut.app` onto its screen, or run from the extracted folder:

```sh
xcrun simctl install booted ./FrameCut.app
xcrun simctl launch booted com.alivahdati.framecut
```

If a different runtime or architecture rejects the package, build the source for that simulator. Do not try to install this archive on an actual iPad.

## First film

1. Choose photos/videos or import from Files.
2. Select and arrange clips. Use the scissors to split at the playhead.
3. Open **Tools and help** for task-based routes to text, audio, layers and other panels.
4. Preview the film and review automatic captions.
5. Tap **Export**, choose quality, then **Export film**. Keep the app open until rendering finishes.

For bugs, report device/OS, steps and expected/actual behavior in [Issues](https://github.com/vahdatiirz/FrameCut/issues). Use synthetic or non-private media.

## Public installation without Xcode

A public TestFlight link requires an App Store Connect app record, an eligible uploaded build and Apple's external testing process. These have not been set up for FrameCut. No TestFlight availability is claimed. [Apple TestFlight guide](https://developer.apple.com/testflight/).

## نصب فارسی

**فعلاً نصب مستقیم از لینک روی آیپد نداریم.** بستهٔ سورس برای ساخت در Xcode است؛ بستهٔ Simulator فقط برای شبیه‌ساز مک است.

برای آیفون/آیپد:

۱. روی مک Xcode را نصب کنید؛ سورس نسخهٔ ۰٫۹ را از Release دانلود و باز کنید.
۲. فایل `FrameCut.xcodeproj` را باز کنید و اجازه دهید وابستگی‌ها دریافت شوند.
۳. در Signing & Capabilities، تیم خودتان و یک Bundle Identifier یکتا انتخاب کنید.
۴. دستگاه را متصل و باز کنید، مراحل اعتماد/Developer Mode را طبق دستور خود اپل انجام دهید.
۵. Scheme «FrameCut» و دستگاه را انتخاب و Run کنید.

با حساب Personal Team محدودیت و تمدید امضا وجود دارد؛ پروفایل معمول آن پس از هفت روز نیاز به ساخت/نصب مجدد دارد. نسخهٔ نصب‌شده روی دستگاه توسعه‌دهنده برای همهٔ دستگاه‌ها قابل توزیع نیست.

برای شبیه‌ساز مک، پروژه را روی شبیه‌ساز اجرا کنید یا بستهٔ آمادهٔ مخصوص Apple Silicon و runtime اعلام‌شده را نصب کنید. فایل شبیه‌ساز روی آیپد واقعی نصب نمی‌شود. برای نصب عمومی بدون Xcode باید انتشار جداگانهٔ TestFlight یا App Store انجام شود؛ در این نسخه انجام نشده است.
