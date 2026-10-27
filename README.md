# Redmoon Mobile — Offline Adventure

Android game rebuilt from the supplied server data and the RMA 7.0 client.

## Play

Install `build/Redmoon-Mobile-v0.7.1.apk` on ARM64 Android 7.0 or newer.
Use the movement pad and ATTACK/HEAL buttons. BAG opens an item grid with separate CHARACTER and JOURNEY tabs. Tap an NPC
to open their dialogue; distant NPCs can be approached automatically.
Gold NPC markers identify interaction locations. Use the upper-right TRAVEL menu for connected locations and the beginner town guide. Progress saves locally, automatically and with SAVE. No server/login needed.
Desktop controls: WASD/arrows, Space to attack, E to heal.

## Current implementation

- 196 server maps with collision, original terrain/object rendering where the
  matching client map is readable; converter recovers 252 client map files.
- 83,543 composed sprite entries, including directional hero/NPC animations;
  identical image payloads are shared to reduce download size.
- Touch movement and simultaneous attack; map selection and minimap.
- Combat, a mana-powered attack, source-derived loot records, inventory, weapon
  and armor bonuses, food, healing purchases, item sales, progression and rewards.
- Source monster identities, spawn bounds and respawn intervals; bounded populations.
- Local saves retain maps, player/enemy state, inventory, equipment, mana and rewards.
- HP/MP use statically recovered formulas; new heroes start with recovered attributes of 10.

## Fidelity limits

Combat damage, special item effects, skill attack, XP thresholds, half-price
buyback and bounty remain reconstruction rules, not verified original behavior. The server dataset is older
than this client; some appearance IDs may refer to different artwork. Walking/running/idle direction mapping now follows the retained Bevy source.
Terrain/object depth sorting is improved but remains approximate.
Unsupported references are retained in client-art.json; nonpositive source
rectangles are skipped following upstream behavior. Missing references remain
transparent or use fallback actors.
Original class mechanics, quests, complete skills/equipment/effects and
multiplayer are unfinished. Exact original attack animations and music-to-map
assignments remain unverified. No working legacy service or validated multiplayer
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

## Retained upstream source

`references/novluno/` contains source snapshots of master, bevy and new_client,
with upstream licenses and exact commits in UPSTREAM.json. Third-party compiled
libraries and game assets are excluded. The converter adopts bevy's corrected
RMD render-depth field (field 6); field 9 is a separate layer/blend flag. Existing
APKs are unchanged until their assets are regenerated and the game rebuilt.

## Version 0.3

- Original walk/run/idle animation sequences and keypad directions; hero RMD/list
  pairing corrected to the upstream character index (0 through 9).
- Animated objects, depth-sorted scenery and actors, original NPC appearances.
- Named original attack/item/coin effects. Optional first client MIDI composition,
  rendered with a replacement General MIDI soundfont; enable Music in BAG / TALK.
- Wall-aware attacks, enemy navigation around obstacles, run toggle.
- Client EXIT rectangles matched to source-documented map destinations. Use nearby
  EXIT from BAG / TALK; unsupported event types are not executed.
- Source-listed zone market stock with deliberately reconstructed offline prices.
- Save backups/recovery and normalized persistent inventory/purchase counts.
- Content-addressed image sharing and visibility-based texture-cache eviction.

Asset regeneration after client_assets.py:

```
python3 tools/client_events.py /path/to/Redmoon
python3 tools/client_sounds.py /path/to/Redmoon
python3 tools/client_music.py /path/to/Redmoon/RLEs/Mid/Rm001.mid
python3 tools/pack_art.py --archive /path/outside/game/unused-art
```

Music rendering requires Linux FluidSynth, a GM soundfont and ffmpeg. The generated
art/audio remains outside Git. Version 0.7 is Android debug-signed with the same
package and development key as the earlier build so an in-place upgrade should
retain saves. No physical Android/iOS device testing has been performed.

## Version 0.4

- Decoded 784 active item records: original attack, defense, healing, mana,
  base prices, class masks, stat/level requirements, equipment slots and range.
- English names recovered through the client message table; 784 original item
  icons now appear in inventory and shops.
- Nine named heroes; equipment checks class and requirements and occupies its
  source slot. Gear contributes its recorded stat bonuses.
- Spend level-up points in BAG. HP/MP and point awards use the statically
  recovered formulas. Starting attributes of 90 remain a chosen offline baseline.
- New equipment/attribute progress persists, with migration for older saves.

Item decoding independently implements documented layout facts from rm-lib
commit `cc1393454b45f9228c5966220d818c2ed4f7b69b`; GPL library code and its
proprietary test files were not copied into this game. Format reference:
https://github.com/briansteffens/rm-lib/blob/cc1393454b45f9228c5966220d818c2ed4f7b69b/docs/RSI.md

Run these after the main asset conversion and before image packing:

```
python3 tools/item_metadata.py /path/to/Redmoon
python3 tools/item_icons.py /path/to/Redmoon
```

The separately checked RMA 6-to-7 update contains 13 files already identical to
this client, so overlaying it adds no missing content. Later Korean packages in
external research reports have not been acquired or validated here.

## Version 0.5 — new-player adventure

Start from the title screen, select NEW CHARACTER, enter a name and choose one
of nine heroes. BEGIN ADVENTURE starts at Street 1 Hospital. Open BAG / TALK and
speak with the Doctor for beginner equipment and guidance. Use TRAVEL to visit
Street 1 and the Backyard; defeat three creatures and return to the Doctor.
The Doctor restores health/mana. Visit the food and weapon shops for source-listed
stock; Street 1 Bank stores gold. MENU returns to Continue/New Character. Creating
a replacement character requires confirmation; there is one active character slot.

The 3.x IP server's `ProcessNewCharacterID` at 0x404a10 initializes four
attributes to 10 and supplies five category-4/index-1 food items plus Street 1/2/3
map items. New characters now use those attributes/items. Normal creation stores
a map sentinel of -1 with coordinates (122,115); that sentinel's complete
resolution remains unverified. The safe hospital start, Doctor gifts, training
quest/rewards, beginner transport, bank convenience actions and five-second
arrival protection are reconstruction choices. They are not presented as the
original introduction. English town names come from preserved `Web/maps.txt`.
Existing saves retain their previous attributes; new starting values apply only
to new characters. Starting heroes cannot be switched through the inventory.

Regenerate destination data with `python3 tools/journey_data.py` after preparing
the supplied server archives. The generated `journey.json` is packaged with the
APK. `game/tests/new_adventure.gd` covers all nine starter classes, services,
training rewards, banking and persistence. `creation_ui.gd` drives the creation,
town travel, combat, Doctor return and food purchase through interface controls.
Use an isolated temporary XDG_DATA_HOME for each test process so tests do not
modify player saves. Rendered suites require an active display (Xvfb works).

## Version 0.6 — readable view and touch name entry

Creation now has nine portrait buttons and a large selected character showcase
with a dark/gold presentation using original Redmoon sprites. The name field has
an explicit EDIT NAME button and a built-in touch keyboard (letters, digits,
space, clear, delete, done and cancel); it does not require Android's native IME.
Physical keyboard editing remains available. A default hero name lets a player
start immediately; an emptied name falls back to the selected hero's name.

Gameplay defaults to 2x zoom. VIEW + / VIEW − adjust the camera between 1.25x and
3x; the preference persists independently of character saves. UI text, health
bars, controls and inventory rows are larger, and objectives have a dark backdrop.
The world transform scales tiles, objects, actors and attack effects together;
HUD and minimap remain at screen scale.

The accessibility suite creates a named character using actual GUI pointer
routing and verifies touch-event name entry through the engine's mouse emulation.
These are desktop renderer/input tests, not Android hardware or OS keyboard tests.

## Version 0.7 — bag, attributes and NPC dialogue

BAG now opens a five-column item grid with icons, quantities, equipped highlights
and All/Gear/Food/Other filters. Tap an item to inspect its name, effects and
requirements, then use, equip or unequip it. Near an active shop, the detail pane
also offers selling one item. The CHARACTER tab shows available points and
per-attribute minus/plus controls, live health/mana previews and APPLY POINTS.
Draft changes do not spend points; closing/resetting discards them. Applying
validates the entire allocation and saves once, rolling it back on save failure.
The HUD and character tab show unspent points. Strength/Dexterity descriptions
refer to equipment requirements; unimplemented original combat effects are not
claimed by this interface.

Tap NPCs in the world for a named dialogue box and portrait. Dialogue offers
contextual Doctor training/healing, merchant stock, bank deposit/withdrawal,
objective help and Goodbye. Tapping a distant NPC follows a recovered walkable
path until in range; manual movement cancels approach. Conversations use new
offline text and services, not a complete recovered original quest interpreter.
Generic quest NPCs do not offer merchant services merely because their zone has
shop stock. JOURNEY retains travel, exits, the offline skill/bounty and options.

The new UI suspends the joystick while modal panels are visible. NPC picking
accounts for camera zoom and HUD clipping. Integration tests use actual GUI
clicks plus touch events at 1.25x, 2x and 3x zoom, and cover stat persistence,
malformed/over-budget allocations, save rollback and automatic approach.

## Version 0.7.1 — contextual Doctor guidance

The Doctor's greeting and WHAT SHOULD I DO NEXT answer now speak from her
perspective. Before training she explains BEGIN TRAINING; after training she
offers COMPLETE TRAINING. Progress guidance reports Backyard defeats, and
completed characters receive exploration guidance. HUD quest reminders remain
separate. Older saves can use her healing service without restarting progress.
