# Validation and builds

Validation date: 2026-10-26. Engine: Godot 4.5.1 stable, standard GDScript build.
All original software was inspected statically; no legacy Windows program,
database, installer, PHP page, TCL script, or network service was run.

## Version 0.7 checks

- 24 Python importer/format tests and four statically recovered-rule tests passed.
- 173 Godot checks passed: 24 core gameplay, nine adventure/persistence, five
  injected multitouch, 13 recovered upstream features, eight market/recovery,
  13 recovered-item/attribute rules, 32 new-adventure checks, 17 creation/UI
  journey checks, 18 accessibility checks, 28 inventory/dialogue integration checks and six
  rendered end-to-end checks.
- Rendered UI tests ran under Xvfb/Mesa, covering movement, attack controls,
  inventory food consumption, music playback and save/reload. Inventory artwork
  and layout were inspected in `analysis/v07-bag.png`.
- Independent item decoding recovered 784 active item records and icons with
  source prices, equipment slots, class masks and requirements. Binary parser
  tests verify known item values and reject truncated records.
- Android export uses Godot 4.5.1, Java 21 and SDK/build tools 35. The APK is
  ARM64, minimum API 24, target API 35, package `org.redmoon.offlineprototype`.
  Signing and archive/content checks are recorded in `analysis/v07-build.json`.
- Character creation, safe hospital start, Doctor introduction/training, named
  town travel, banking and source-price food purchase were exercised. All nine
  heroes received compatible starter gear. Title/creation/Continue and replacement
  confirmation were verified through the UI.
- Name entry was driven through GUI clicks and a simulated touch event. The
  built-in keyboard, editable name, hero cards, new-character start and zoom
  persistence passed. Large text and camera output were inspected at 1280x720.
- The new item grid, explicit use/equip/unequip actions, stat draft/apply/save
  rollback, NPC picking at three zooms, walking into talking range and merchant
  dialogue passed. A joystick interception regression was reproduced and fixed
  by disabling joystick input while the new panels are open.
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

## Version 0.7.1 hotfix

83 targeted checks passed: ten Doctor dialogue regressions, 32 new-adventure
checks, 13 item/attribute checks and 28 rendered inventory/dialogue checks.
Doctor greeting, help and post-heal responses use speaker-specific guidance.
Older saves receive a working healing choice without changing their progress.
The prior 173-check full suite and parser checks are recorded above; they were
not all repeated for this text/service hotfix. No phone test was performed.

## Version 0.8 audio and preservation update

198 Godot checks passed: the previous 173 checks, ten Doctor dialogue checks
and 15 music checks. The music suite captures mixed PCM with AudioEffectCapture;
it verifies non-silent output, real silence at zero volume, volume restoration,
automatic playback, persistence, next track, hospital theme selection, fallback
and audio panel fit. The 24 Python importer tests and four recovered-rule tests
also passed. No physical Android device was tested.

48 source MIDI hashes match the existing client and every converted track reaches
the end of its source duration (some have instrument release tails). Five themes
and 20 map assignments pass the conservative cross-client gates. Blood Sun's
custom gameplay tables, recordings, and client code are excluded. Build/signing
and packaged-audio verification are in `analysis/v08-build.json`.
