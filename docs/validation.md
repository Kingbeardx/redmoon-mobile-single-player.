# Validation and builds

Validation date: 2026-10-26. Engine: Godot 4.5.1 stable, standard GDScript build.
All original software was inspected statically; no legacy Windows program,
database, installer, PHP page, TCL script, or network service was run.

## Version 0.4 checks

- 24 Python importer/format tests and four statically recovered-rule tests passed.
- 78 Godot checks passed: 24 core gameplay, nine adventure/persistence, five
  injected multitouch, 13 recovered upstream features, eight market/recovery,
  13 recovered-item/attribute rules and six rendered end-to-end checks.
- Rendered UI tests ran under Xvfb/Mesa, covering movement, attack controls,
  inventory food consumption, music playback and save/reload. Inventory artwork
  and layout were inspected in `analysis/v04-inventory.png`.
- Independent item decoding recovered 784 active item records and icons with
  source prices, equipment slots, class masks and requirements. Binary parser
  tests verify known item values and reject truncated records.
- Android export uses Godot 4.5.1, Java 21 and SDK/build tools 35. The APK is
  ARM64, minimum API 24, target API 35, package `org.redmoon.offlineprototype`.
  Signing and archive/content checks are recorded in `analysis/v04-build.json`.
- Original Windows executables remain unexecuted. Source archives and extracted
  artwork are excluded from Git. Third-party parser licenses remain attached.

## Limits

No Android phone/emulator, iOS device or macOS/Xcode build was available.
Injected input tests do not establish physical touchscreen or mobile performance.
No iOS IPA exists. Device lifecycle, battery and platform graphics need testing.

Original maps/art/audio, inventory, equipment, source-listed shops, bounded
spawn/respawn/drop handling and selected exits are integrated. Combat damage,
XP thresholds, class skills, quest scripts, special effects and full event logic
remain partial or reconstructed. There is no functioning legacy multiplayer
service or verified network implementation. Some server/client artwork IDs
may disagree because these resources come from different community versions.

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
