# Original skill catalogue and offline implementation

`tools/skill_import.py /path/to/Redmoon` generates `game/data/skills.json` and
imports original skill icons. It uses the 3.8 server's 38-byte suffix, with
English messages matched by server class and icon to RMA's CTF references.
No rm-lib implementation is copied; its documented layout is a format reference.

The original server contains 114 named player entries (105 normal, nine DP),
including distinct honor variants of several attacks. All 114 have localized
names, descriptions, icons and requirements. 70 entries have supported offline
behavior; 44 remain references and cannot be cast or assigned. This is not a
claim of 70 unique skills, complete class trees or original combat fidelity.

36 matching RMA records differ from the server in one or more numeric fields.
In particular, original Philar Heal unlocks at level 10 and Soul Sphere at 50;
RMA swaps those levels. Original values take precedence. Server hero 6 references
CTF character 7 (Lunarena); server hero 7 references CTF character 6 (Kitara).
The importer keeps both IDs and uses the CTF reference for the displayed roster.

`tools/skill_evidence.py` statically disassembles named original functions, without
running them, into ignored `analysis/skills-evidence.asm` and records hashes and
coverage in `analysis/skills-evidence.json`:

- `CheckSkillRequirement`, 0x43c7b0: class, level and signed honor threshold.
- `DecreaseMP(SKILL_INFO*)`, 0x439710: fixed cost or truncated percentage of
  maximum MP; 100% and above consumes maximum MP.
- `UseSkillAlone`, 0x4478d0: Cure/Heal convert one MP to two HP; many buff timers
  use base duration plus effective Spirit / 20. Recover restores missing HP.
- `UseSkillUserCure`, 0x448700: targeted cure conversion and multiplayer details.
- Serializer and attack-adjustment functions establish field offsets/context.

Implemented modes: selected direct/area attacks, healing, Disguise, Will Power,
Sharpshoot, Hasten, Absolute Defense, Barrier, Faster Reload, Eye of the Hawk,
Enticement, Fetters, Hold and Slow. Requirements and multipliers come from the
original table. Damage uses the existing offline base damage model. Effects
such as weakening, shields and crowd control are offline adaptations rather
than complete translations of the original status and attack pipelines.
Targeted ally healing applies to the player in single-player.

The 0.8-second per-skill recovery is an offline pacing rule, not a recovered
original cooldown. Failed casts consume no MP. Training Strike remains a clearly
marked non-original fallback. Three assignable slots, cooldowns, buffs and honor
are saved; timer restoration subtracts elapsed real time. Old saves get suitable
class defaults. New characters start neutral. Original signed reputation changes now apply on
creature defeat up to the initial ±100 cap. Higher caps require quest flags
that have not been restored; branches above that cap remain locked.
DP, resurrection, gates, PvP/party mechanics, advanced effects and the complete
original combat pipeline are not implemented. Blood Sun's modified 746-skill
catalogue is retained for comparison; it is not merged into original gameplay.

Run `python3 -m unittest discover -s tests`, `tools/test_recovered_rules.py`, and
Godot scripts `res://tests/skills.gd` / `res://tests/skill_ui.gd`. The latter tests
actual GUI input, binding and touch casting; use a rendered display for captures.


v0.11 adds Sandman/Morpheus/Obscurity sleep (damage wakes the target), Cold Cell,
Dark Curtain, Dark Sword, Ice Arrow, Vampiric Touch, Mistress Vampire, Horror,
and two additional invisibility variants. The damage, crowd-control and AI
integration remain offline adaptations: blindness currently prevents melee hits,
freeze prevents movement/attacks, fear drives nearby creatures away, and
invisibility suppresses aggression until the player attacks. Original lifesteal
ratios are 30% for Vampiric Touch and 50% for Mistress Vampire, applied to actual
HP removed (bounded on overkill). The full original hit/defense pipeline is not
restored. Respawns clear status effects from the previous life.

Original projectile art is decoded for 20 supported entries from the referenced
Bul RMD/RLE sequences. Direction order is the eight original sequence slots;
empty rows remain transparent frames. Flight timing and rendering integration
are reconstructed; combat resolves immediately. No substitute graphics or
Blood Sun gameplay tables are admitted by this importer.
