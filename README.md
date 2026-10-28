# Redmoon Mobile — Offline Adventure

Android game rebuilt from the supplied server data and the RMA 7.0 client.

## Play

Install `build/Redmoon-Mobile-v0.9.apk` on ARM64 Android 7.0 or newer.
Use the movement pad and ATTACK/HEAL buttons. BAG opens an item grid with separate CHARACTER and JOURNEY tabs. Tap an NPC
to open their dialogue; distant NPCs can be approached automatically.
Gold NPC markers identify interaction locations. Use the upper-right TRAVEL menu for connected locations and the beginner town guide. Progress saves locally, automatically and with SAVE. No server/login needed.
Desktop controls: WASD/arrows, Space to attack, E to heal, Q for Strike, R for food.

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
art/audio remains outside Git. Version 0.9 is Android debug-signed with the same
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

## Version 0.8 — original client music library

Music starts automatically, with 48 MIDI compositions from the existing RMA
client rendered to offline Ogg audio. Rendering uses replacement General MIDI
instruments, normalizes loudness, and preserves the complete compositions rather
than the previous five-minute limit. The old player defaulted off, played only
one quiet track and reduced it by another 20 dB. Music volume now defaults to
70%, with true mute, persistent preferences and previous/next controls at
BAG → JOURNEY → MUSIC & SOUND. A title-screen button also toggles music.
Playback continues through menus and recovers after application pause/resume.

The Blood Sun installer was inspected and extracted as data without execution.
Its custom item/skill/stat/quest tables and recordings are not imported. Five
conservative music-theme matches contribute 20 map assignments, gated on an
identical MIDI in both clients, strong melody/timing similarity, a clear margin
over the next match and matching map IDs/dimensions. This is compatibility
evidence for community-client themes, not authentication of an official JCE
music assignment. Unmatched zones use the existing client soundtrack playlist.
Two MIDI files changed in Blood Sun are excluded from matching; the game keeps
the RMA versions. No Blood Sun gameplay rules or executable code is bundled.

Regenerate the soundtrack from original client inputs:

```
python3 tools/match_music.py /path/to/Redmoon /path/to/extracted/BloodSun --output analysis/music-matches.json
python3 tools/music_library.py /path/to/Redmoon --blood-sun /path/to/extracted/BloodSun --matches analysis/music-matches.json
```

Omit the Blood Sun options to render only the existing client soundtrack.
Conversions cache MIDI and soundfont hashes. Linux FluidSynth, a GM soundfont,
ffmpeg and the analysis requirements are needed. Original input resources and
converted audio remain outside Git. `music_playback.gd` checks PCM at the actual
engine mixer, mute/unmute, persistence, missing-file fallback and zone selection.
Desktop mixer validation is not a physical Android speaker test.

## Version 0.9 — compact mobile HUD, original profiles and reliable respawns

The game canvas expands to wide phone aspect ratios. Full-width header/footer
mats are removed: health/mana/XP gauges, a character portrait, compact location
and objective chips, and an icon hotbar float over the world. Attack, Strike,
healing charges and quick food have direct touch controls; the existing mana
attack is visible with its cost/cooldown. Save and optional minimap are in
BAG → JOURNEY. Zoom controls and readable text remain available. Notifications
fade instead of permanently occupying the bottom of the field.

Shops default to compatible stock, distinguish EQUIP NOW from missing
requirements, list permitted heroes, disable incompatible purchases and enforce
class restrictions in the backend. Gear that needs more levels/stats can be
bought deliberately with BUY FOR LATER. Philar and Azlar have no physical-weapon
eligibility in the recovered tables; compatible clothing remains available.
Original English bios and weapon hints are recovered from Message.ctf by
`python3 tools/hero_profiles.py /path/to/Redmoon`. Creation offers STORY, SKILLS &
EQUIPMENT. The profile clearly distinguishes playable reconstructed actions from
incomplete original class skill trees.

The original name table establishes Kitara as ID 6 and Lunarena as ID 7; the
previous roster labels were reversed. Saves now record roster_version=2; older
IDs 6/7 migrate to preserve the character name selected in the older UI. Items,
levels, currency and progress remain; incompatible equipped items stay in the
bag when removed from equipment.

Respawn timers retain recovered source intervals. Bounded populations previously
sampled slow/rare entries too heavily; starter areas now include ordinary fast
spawn groups. Timers advance during menus, remember time spent away, and return
enemies to their recorded home positions. Older slow-only or empty outdoor save
states receive source-backed common spawns. Rare source timers remain long.
The offline population cap and simplified combat remain reconstruction choices.

## v0.10 original character skills

BAG → SKILLS shows the chosen character's original skill list with descriptions,
level/honor/weapon requirements and original icons. Assign an available skill to
any of three touch slots. An empty slot opens the skill menu. Keyboard: 1/Q, 2,
3 cast slots; K opens skills. Training Strike remains an explicit offline fallback.

All 114 original player entries are catalogued; 49 entries have reconstructed
behavior and 65 remain non-playable references. These counts include honor
variants. Original server requirements take precedence over modified RMA values.
Honor rewards and DP are not yet reconstructed; honor branches remain locked at
neutral honor. Damage/effects run in the offline combat model, not a fully restored
original server. See [skill evidence and limits](docs/skills-reconstruction.md).

Regenerate with `python3 tools/skill_import.py /path/to/Redmoon`. The importer
requires the supplied 3.8 server skill table and a decoded client-art manifest.
Original icons and generated game data remain outside source control.

## v0.11 expanded effects and original honor gains

61 original skill entries now have reconstructed behavior; 53 remain references.
New effects include sleep (wakes on damage), freeze, blindness, fear, invisibility,
and two life-draining attacks. Original projectile art is included for 20 entries;
flight timing and combat effects remain adapted to the offline model.

Defeating creatures with nonzero original reputation now changes honor using the
server's signed arithmetic. Creature labels show the prospective change, and
JOURNEY shows your honor and cap. The initial cap is ±100; original quests that
raise it are not restored. Source faction groups are retained in the bounded
population, including old saves. Respawns clear effects from the previous life.
See [honor evidence and limits](docs/honor-reconstruction.md).

## v0.12 monster casting and protection

70 original player skill entries now have reconstructed behavior; 44 remain
references. Monster AI uses 23 supported original skill entries with sourced
IDs/ranges/intervals. Cleansing, mental protection, Scarecrow and Roar now work.
SKILLS → ACTIVE EFFECTS explains live impairments and buffs. Control effects use
short offline safety limits rather than the complete original status formulas.

Kitara/Lunarena portraits, equipment checks and biography examples now follow
the original server-to-display class mapping. Existing characters keep their
identity and items. See [evidence and limits](docs/monster-skills-and-protection.md).

## v0.13 recovered story progression

At original level 50, JOURNEY → STORY opens the recovered Spy / Microfilm /
Geographer / Kasham / Esper chapter. Complete its objectives and NPC conversations
to raise honor caps from 100 to 200, 300 and 400. The original level requirement,
dialogue text, quest targets, flags and evidenced honor/map rewards are retained;
interaction glue is rebuilt because 43 event-script slots are explicitly removed
in both supplied server packs. Original quest XP and later chapters remain missing.

Guide travel, map tracking, protected quest items, retry handling and persistent
boss damage keep the chapter playable offline. Fixed spawn quantities and
separated NPC anchors fix the missing Spy / untappable Geographer problems.
Regenerate with `python3 tools/story_import.py /path/to/Redmoon`.
See [story evidence and limits](docs/story-reconstruction.md).

## v0.14 combat stances

Hide, Red Halo, MadSpin and Psychic Boost now have functional offline effects,
raising supported player entries to 74/114. Original class/level/honor/cost and
recovered duration paths are retained. Hide has a visible END HIDE touch action;
reflection follows real post-shield HP loss; basic attack speed uses the strongest
active rate. Stances save and expire correctly.

See [combat stance evidence and limits](docs/combat-stances.md). This remains an
offline reconstruction: full original damage/accuracy, DP, multiplayer and later
story chapters remain incomplete.

## v0.15 extended recovery

95 player entries and 24 monster entries now have offline behavior. The pass adds
all nine Danger Point specials, source XP and first-chapter XP rewards, original
class-specific stat growth with old-save migration, running/stamina/rest recovery,
aimed Warp and rush attacks, support effects, monster poison, original attack
poses, creature selection and usable map items. Existing music, towns, gear,
progress and the first story chapter remain playable.

See [recovered systems and formulas](docs/recovered-systems.md) and the measured
[remaining recovery inputs](docs/recovery-status.md). This is still an offline
reconstruction, not the entire original MMORPG. The latter report distinguishes
missing quest/map/art inputs from unimplemented effects whose data is already here.

Additional regeneration tools after the existing asset pipeline:

```sh
python3 tools/skill_import.py /path/to/Redmoon
python3 tools/character_actions.py /path/to/Redmoon
python3 tools/app_icon.py /path/to/Redmoon
python3 tools/attribute_growth.py
python3 tools/recovery_inventory.py
```

Original art, client/server binaries and archives remain outside Git.
