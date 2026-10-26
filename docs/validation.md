# Validation and builds

Validation date: 2026-10-26. Engine: Godot 4.5.1 stable, standard GDScript build.
All original software was inspected statically; no legacy Windows program,
database, installer, PHP page, TCL script, or network service was run.

## Completed checks

- All three RARs extracted successfully with 7-Zip 25.01. Re-extraction matched
  every file hash. The libarchive extractor initially reported a CRC error;
  7-Zip successfully verified/extracted the archives, so reproduction uses 7-Zip.
- Seventeen Python importer tests passed, including every supplied SMM file,
  byte-for-byte item/skill table reconstruction, malformed row handling, and
  truncated/oversized input rejection. Four recovered-rule tests passed.
- Godot imported the project and ran 24 gameplay smoke checks: real map/data
  loading, boundary blocking, movement, wall tunneling, combat cooldown and XP,
  healing, save/load, map-state persistence, and malformed-save rejection.
- Five Godot viewport-injected touch checks passed: joystick press/release,
  second-finger attack, joystick ownership, and single-charge healing. These
  test the input routing in the game, not physical touchscreen hardware.
- Rendered the real main scene using Xvfb/OpenGL Mesa llvmpipe and inspected
  `analysis/prototype-preview.png` at 1280×720. It shows the recovered map grid,
  source-derived monster IDs, placeholder actors, touch controls, and HUD.
- Android debug export completed using the official Godot 4.5.1 template,
  OpenJDK 21, Android platform/build tools 35.0.0, and a local debug keystore.
  `apksigner verify --verbose` reports valid APK signature schemes v2 and v3.
  Package: `org.redmoon.offlineprototype`; ARM64; min API 24; target API 35.
- APK contents and Android manifest were inspected for packaged game data,
  architecture, minimum SDK, and offline permissions.

The build can log an ADB-daemon connection warning in this container: no Android
device is attached. That warning is separate from the completed signed APK export.

## Not verified or not implemented

No Android emulator/phone, iPhone/iPad, or Mac/Xcode runtime test was performed.
There is no iOS IPA or App Store/Play Store release build. Performance, battery,
device-specific graphics, physical multitouch, and lifecycle behavior require
device tests. No claim of original gameplay fidelity follows from prototype tests.

There is no original artwork/audio, faithful combat model, inventory/equipment,
class system, skill execution, quests, shops, original respawns/drops, or event
interpreter. Extracted data and the separate statically recovered rule subset
are retained for those later implementations.

## Android reproduction

1. Install Godot **4.5.1 standard** and matching export templates.
2. Install a supported JDK (17 or later; this build used 21), Android SDK
   platform-tools, `platforms;android-35`, and `build-tools;35.0.0`.
3. In Godot Editor Settings → Export → Android, set Java SDK and Android SDK
   paths. Let Godot create its debug keystore. Do not reuse the prototype's
   debug identity as a release signing identity.
4. Open `game/project.godot`, or use the CLI after setting those editor paths:

```sh
mkdir -p build
godot --headless --path game --export-debug Android /absolute/project/build/redmoon-offline-android.apk
```

The Android preset uses the standard template (Gradle disabled), which already
targets API 35. SDK overrides must stay empty for this export mode. The project
enables ETC2/ASTC import support required by the mobile exporter. No custom Gradle
plugin or Android-specific gameplay code is needed.

The package includes all recovered JSON maps and tables via explicit include
filters, and excludes game test scripts. SDKs, signing keys, and original server
files are outside the project export.

## iOS

Use the same `game/project.godot` on macOS with Godot 4.5.1 iOS templates and Xcode.
In the iOS preset choose your own bundle ID and Apple team, then export the Xcode
project and select your signing/profile/device in Xcode. The team field is
deliberately unset: this workspace has no user Apple development identity.
An iOS export preset is configuration, not evidence of an iOS build or device test.
