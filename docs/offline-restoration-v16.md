# Offline restoration v0.16

The build runs 108 of the 114 recovered player entries and 24 of 36 monster
entries. This is a playable reconstruction, not a complete original MMORPG.

## Evidence and implementation

All names, descriptions, class/level/honor requirements, costs, icons and source
multipliers come from the supplied server skill00.rmi and client Message.ctf.
The new runtime calculations below are explicitly **offline adaptations**. The
skill menu includes that distinction. Original requirements remain enforced.

| Entry | Playable behavior | Adapted portion |
|---|---|---|
| Voodoo | Link one opponent; mirror actual incoming HP loss | Six-tile link; no poison reflection; single local target |
| Soul Drinker | Sword damage transfers finite creature MP/SP | Transfer limited to actual HP damage and remaining pools |
| Drain | Damage transfers HP/MP/SP | Same finite pools; no overkill healing |
| Psycho Kinesis | Automatically collect visible ground loot at distance | Ten tiles while active; ordinary pickup 1.5 tiles |
| Evasion | Sometimes avoid physical damage | 20% independent chance; no psychic/poison immunity |
| Snipe | Extend gun attacks to visible distant opponents | Ten tiles |
| Dysperse | Basic attack splashes nearby creatures | Three targets, two-tile radius, half damage |
| Chain Reaction | Basic attack chains between creatures | Three jumps, three-tile hops, 25% falloff per jump |
| Starlight | Self attack/protection buff | 20% attack / 20% damage reduction; no party simulation |
| Soul Crush | Curse weakens a creature and prevents healing | Damage/defense factor 70%; original duration inputs |
| Holy Shield | Reduce incoming damage | Divide by original multiplier 120/100 |
| Damned Armor | Reflect actual HP damage | Original 50 multiplier interpreted as 50% reflection |
| Purity of Heart | Accelerate Danger Points | Original 70 multiplier interpreted as a 100/70 gain factor |

Creature MP pool initialization uses `50 + (Spirit/15)*(Spirit/10)`, matching
CMopInfoFile::ReadMopInfo at 0x476577..0x476588. The 2000 SP pool and transfer
amount are offline choices. Draining does not change the native monster casting
requirements, which are not fully reconstructed. Depleted pools cannot generate
further stolen energy; respawning creates fresh pools. Map saves preserve them.

Scatter and Chain Reaction replace each other. Secondary hits respect walls,
cannot hit the same creature twice in one attack, and do not recurse. Reflection
uses actual HP lost after defenses. Curse and Voodoo expire across map transitions.
New player buffs use existing save validation and duration handling.

## Loot and save compatibility

Ranged kills leave visible gold loot markers; approaching collects items.
Psycho Kinesis collects them remotely without crossing walls. Nearby kills retain
automatic pickup. Uncollected loot saves with each map. Full ground capacity or
unknown item metadata falls back to inventory delivery rather than losing items.
The existing first-item drop-selection and five-gold rewards remain provisional;
this update does not claim to restore the native loot probability model.

The earlier poison tick-progress save repair is included. Large HP/MP and skill
cost labels use K/M abbreviations to fit the mobile HUD; exact HP/MP remain in
tooltips. Existing Android package identity and signing certificate are retained.

## Remaining limits

Gate, Recall, ally Teleport and Resurrection still require an ally/portal system.
Concentration and Rabbit's Foot require a properly integrated accuracy model.
Those six entries remain visibly unavailable. Later quest programs still contain
43 Removed slots. Full original damage, accuracy, armor, monster health, drop
probabilities, multiplayer and later story remain incomplete. The native monster
health formula has been identified, but is not enabled independently of the
corresponding damage model. No legacy executable was executed.

Android is exported and signed; physical-device performance is untested here.
See recovery-status.md for exact missing/mismatched resource candidates. That
list is not proof that every listed candidate requires an independent file.
