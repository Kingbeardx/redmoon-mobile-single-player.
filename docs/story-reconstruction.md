# Recovered first story chapter (v0.13)

`tools/story_import.py /path/to/Redmoon` builds the original dialogue/NPC/goal
catalogue and losslessly frames `EventScript.res`. Both supplied server archives
contain the same 11,692-byte file, SHA-256
`59fefc73ff582ef5d8db518e4b78d1e9d398625533be39720df85111afc75422`
(see the generated evidence manifest for the measured full hash). The table has
84 slots; 43 explicitly contain `Removed`. These are missing event-script bodies,
not 43 missing archive files. RMA's client counterpart contains only 24 slots.

The decoder retains the map hint, unknown DWORD, server-check flag, condition,
client action and server action, including serialized strings for exact byte
round trips. It never executes arbitrary commands. `CEventProcessInfo::Serialize`
(0x405670) and the server-action getter establish framing/order.

`tools/story_evidence.py` records static disassembly and hashes. Original native
checks establish level 50 for starting the Spy story, its started/completed flags,
Microfilm type/index 5:1, and later readiness flags. Original CTF messages
0:7:181–235 supply conversations, the Street1 quiz answer and chapter goals.
Global `EventInfo.rse` gives NPC roles 27/28/29; this identifies the quest
Geographer in Street 3 rather than the other Geographer who runs a shop.
Original spawn files identify Spy 90 in map 74 and quest Esper 92 in map 72.

Playable path:

1. Reaching level 50 starts flag 0x1. Defeat the Spy in his house and recover
   Microfilm. Rebuilt encounter glue sets 0x2; honor cap becomes 200.
2. Speak to the Archeologist in Downtown 2. Answer the original microfilm test.
   The Street1 answer consumes the film and sets 0x4. A wrong answer confiscates
   it; the encounter can be retried so the save is not stranded.
3. Ask the Street 3 Geographer to make a map. Set 0x8; cap 300. The original
   `SaharaMiniMapQuestEnd` handler adds 30 absolute honor if already non-neutral.
4. Accept Kasham's Esper mission (0x10), defeat the quest Esper in Sahara Dungeon
   1 (0x20), then report to Kasham (0x40). Cap 400. The original `KasamQuestEnd`
   handler adds 50 absolute honor if non-neutral and adds item 5:102, Sahara1 Map.

The removed scripts' dialogue timing, choice routing and boss reset glue are
reconstructed. This is not a verbatim original chapter restoration. Original
quest XP amounts require additional recovery and are not invented here; normal
offline combat XP still applies. Flags/caps and the two absolute-honor awards
follow the native handlers. Later chapters, cap flags 0x400/0x2000, party travel
and their prerequisites remain unavailable. Source level gating is retained.

JOURNEY → STORY provides progress, original objectives, unlocked guide travel and
map tracking. Guide transport and arrivals near NPCs are offline conveniences.
All actions validate the original NPC's map/location, prerequisites and existing
rewards. Consumed items/flags roll back on save failure. Old saves default to an
unstarted chapter, automatically starting when eligible. Microfilm is protected
from sale. Quest flags, boss damage and rewards persist.

The bounded spawn sampler now respects per-group quantities. Map 74 contains one
Spy and two guards, with original coordinates retained. Fixed source points may
spawn within the normal three-tile safety radius; arrival grace still applies.
The offline boss HP is derived directly from Constitution (2000/3500), not a
claim about the original monster HP formula. HP bars and reloads support those
values. Required absent/dead encounters can be rebuilt on re-entry until their
objective is complete, compensating for removed reset scripts and huge source
respawn timers. Boss damage is kept when retreating from a living encounter.

NPCs sharing a roaming rectangle previously overlapped at its center. Stable
anchors now separate colliding NPCs within their original bounds, retaining fixed
points and unchanged centers when possible. This is static offline placement,
not the original roaming AI. It makes the Geographer and surrounding NPCs
individually tappable and stays deterministic across visits.

Tests include both original event-file byte round trips, deleted-slot detection,
original quiz/roles/targets, the entire backend chapter with retry/save-failure
cases, quantity/HP persistence, NPC placement and a rendered touch playthrough.
The latter defeats both bosses using actual attack, spell and heal controls and
completes the NPC conversations through GUI input.
