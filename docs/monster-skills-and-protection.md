# Monster casting and protection (v0.12)

All 36 original monster-skill records are decoded from the original server RMI.
23 entries have supported offline behavior: direct/physical damage, self-healing,
root, blindness, sleep, freeze and slow. 13 composite/scripted entries remain
unsupported, including summoning, theft and ambiguous healing/stealing records.
They are skipped explicitly. No original binary is executed.

The source MOPINFO skill IDs, first/second slots, intervals and RMI ranges feed
`monster_skills.gd`. Interval numbers are interpreted as milliseconds. New casts
wait an initial interval; interrupted creatures cannot cast. Arrival grace and
line of sight are respected, and melee casters close enough to use range-one
skills. Damage uses the existing offline base of four and the source skill
multiplier; it is not the full original attack/stat pipeline. Monster healing
currently affects the caster, not allied groups. No monster MP pool is simulated.
Original projectile art is now decoded for 23 player/monster entries combined.

Player impairments persist with real-time expiry and are visible in the HUD and
SKILLS → ACTIVE EFFECTS. Offline safety rules cap root/freeze/sleep at three
seconds and other admitted impairments at six seconds; control expiry or waking
from damage grants two seconds of control resistance. Root blocks movement;
freeze/sleep block attacks and ordinary skills. Consumables and cleansing remain
usable. Blindness blocks basic/physical attacks; slow halves movement. These are
playable adaptations, not claims of original probability/duration formulas.

Nine additional player entries are admitted:

- Awakening and Sweet Water remove existing impairments, with no charge on an
  empty cleanse.
- Dispel and Free Soul cleanse and provide temporary impairment protection.
- The two Mind Shields and Mind Barrier prevent new admitted impairments.
- Scarecrow blocks three damaging hits, saving remaining charges and refusing
  an active refresh. Charge behavior follows the original description; the
  complete original hit-success pipeline remains unimplemented.
- Roar extends nearby aggression from the offline radius eight to fifteen.
  Its gathering behavior is reconstructed; that radius is not an original value.

Static `UseSkillAlone` and `DoSkillEffect` evidence establishes timer argument
scales: Free Soul and Mind Shield use 200 ms units; Scarecrow also uses 200 ms;
Mind Barrier and Roar use 1000 ms. Mind Shield divides effective Spirit by ten,
while these other timers use twenty. These recovered scales apply to the new
entries; other parts of the combat/status pipeline remain provisional.

CTF displayed heroine IDs differ from server/CHR/equipment IDs. Display ID 6 is
Kitara but uses server/CHR 7; display ID 7 is Lunarena but uses server/CHR 6.
The skill importer already kept both IDs. Portrait rendering, item restrictions,
allowed-character labels, tutorial gear and biography examples now use the same
mapping. Saves retain their displayed identity; incompatible old equipped gear
is unequipped while the item stays in inventory.

Coverage: 70/114 player entries reconstructed, 44 reference-only; 23/36 monster
entries supported. Original honor-cap quests, DP, ally/party transport, advanced
combat effects and full original formulas remain incomplete.
