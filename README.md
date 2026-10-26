# Redmoon Mobile — Offline Adventure

Android game rebuilt from the supplied server data and the RMA 7.0 client.

## Play

Install `build/redmoon-mobile-adventure.apk` on ARM64 Android 7.0 or newer.
Use the movement pad and ATTACK/HEAL buttons. BAG / TALK opens inventory,
equipment, the skill attack, a one-time offline bounty and nearby NPC shops.
Gold NPC markers identify interaction locations. Select maps from the upper-right
menu. Progress saves locally, automatically and with SAVE. No server/login needed.
Desktop controls: WASD/arrows, Space to attack, E to heal.

## Current implementation

- 196 server maps with collision, original terrain/object rendering where the
  matching client map is readable; converter recovers 252 client map files.
- 50,660 composed client images and 58 animated appearances, including nine heroes.
- Touch movement and simultaneous attack; map selection and minimap.
- Combat, a mana-powered attack, source-derived loot records, inventory, weapon
  and armor bonuses, food, healing purchases, item sales, progression and rewards.
- Source monster identities, spawn bounds and respawn intervals; bounded populations.
- Local saves retain maps, player/enemy state, inventory, equipment, mana and rewards.
- HP uses the statically recovered formula at the chosen starting Power of 90.

## Fidelity limits

Combat damage, item effects/prices, skill attack, XP thresholds and bounty are
reconstruction rules, not verified original behavior. The server dataset is older
than this client; some appearance IDs may refer to different artwork. Animation
state/direction selection is partial. Terrain/object occlusion is approximate.
3,512 unsupported/invalid conversion references are logged in client-art.json;
missing references remain transparent or use fallback actors.
Original class mechanics, quests, complete skills/equipment/effects, audio and
multiplayer are unfinished. No working legacy service or validated multiplayer
protocol is available in this project. The Windows binaries were never executed.
Android was built and statically verified; no physical Android device was available.
iOS export configuration remains available, but no iOS binary was compiled.

## Rebuild

Use Godot 4.5.1 standard with its matching templates. Configure Android SDK and
JDK paths in Editor Settings, then export the Android preset. It produces an
ARM64 debug APK, minimum API 24, target API 35, without INTERNET permission.

The source commit/bundle excludes proprietary binaries, downloaded archives and
large converted artwork. To regenerate art, download/extract
https://download.rmadvanced.com/RMA-7_0.zip outside the repository and run:

```
python3 tools/client_assets.py /path/to/Redmoon
```

The converter follows the public-domain parser source at
https://github.com/cjschneider2/novluno. Sparse LST IDs are resolved by ID, not row
position. PNG payloads use `.pngdata` so Godot does not import tens of thousands
of redundant standalone textures; the renderer creates/caches textures on demand.
The source bundle includes generated JSON game tables; original server archives
can also regenerate them with `tools/prepare_game.py`.

```
python3 -m unittest discover -s tests
python3 tools/test_recovered_rules.py
godot --headless --path game --script tests/smoke.gd
godot --headless --path game --script tests/input_smoke.gd
godot --headless --path game --script tests/adventure.gd
```

`game/tests/end_to_end.gd` runs the rendered UI/gameplay/save flow with an active
display. Tests that perform gameplay actions can write local prototype progress;
use a separate test OS account/data directory for installed-player testing.
