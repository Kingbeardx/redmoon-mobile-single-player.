# Extended recovery pass (v0.15)

The pass integrates 95/114 player skill entries and 24/36 monster entries into
the offline model. Reference-only entries are visibly marked in the skill menu.
The full original accuracy, base attack/defense, monster HP and loot pipelines
are still not implemented. See `recovery-status.md` for measured missing inputs
and the distinction between absent files and further engineering work.

## Native arithmetic and progression

- Constructor `0x4422f7..0x442388` initializes level-one XP to 20, builds subsequent
  requirements cumulatively from level squared with century-boundary weights,
  then multiplies entries 900..998 by eight. `recovered_combat.gd` preserves the
  original uint32 arithmetic. The normal solo award cap is one tenth of the
  current requirement. Level-up resets XP, restores HP/MP and awards the native
  two points, or three at a multiple of 100. Level 1000 is the ordinary cap.
- The class table at constructor `0x40ad94..0x40ae89`, consumed by the four
  `Do*Up` methods, grants 8..20 stat units per spent point. It is not one unit per
  point. `attribute_growth.py` interprets those actual MOV instructions without
  executing them; a test compares all 36 values with the runtime table. The
  displayed Kitara/Lunarena identities use their corrected server IDs. Staged
  previews include these class rates. Existing offline adventures convert their
  old one-unit allocations once, keeping unspent points; old XP preserves the
  fractional progress toward the next level.
- `InitializeDPMax` (`0x434820`) uses `50 + floor(P²/150)` through Power 10,000,
  and the HP-style product of truncated divisions above that threshold.
  `DecreaseHP` (`0x439220`) fills DP from the applied damage argument up to that
  maximum. Damage blocked by Hide/Scarecrow or fully absorbed by a mana shield
  grants no meter. The nine original class specials require full DP and consume
  it only on a valid cast. Their recovered base is `50 + floor(level²/6)`, with
  each original skill's multiplier, range and area/single targeting. They cost
  no MP. New characters have their special in the third action slot.
- Running spends SP per travelled tile using rounded `250/sqrt(effective Dex)`.
  The native cap is 2000. Nimble support contributes Spirit/4 to running Dex;
  it does not bypass equipment requirements. Ten-second recovery restores SP
  first, then HP, then MP. HP/MP recovery uses truncated ten-percent increments;
  Philar gets double HP recovery. Casting and valid attacks restart recovery. Recovery, movement batching and pausing are
  integrated into the offline loop, not a recreation of network packet timing.

## Story rewards and admitted effects

Original first-chapter XP is now recovered: Spy completion uses XP-table entry
100 divided by 50, the Geographer uses entry 200 divided by 50, and Kasham's
report uses entry 300 divided by 50. The ordinary award cap still applies. These
rewards are guarded against replay and roll back with flags/items if saving
fails. No inferred gold reward was added. The script interaction glue remains a
reconstruction because the original programs were explicitly removed.

Warp has an explicit visible-ground targeting step, collision/line-of-sight
validation and an offline reach of ten tiles. Slash and Dash rush a selected
creature and hit a narrow corridor along the travelled path. Tap selection has
a visible marker. Blocked or out-of-range attempts keep MP. These targeting and
corridor details are offline adaptations around the recovered requirements.

Berserker doubles basic/weapon-skill power and halves base Power, lowering HP/DP
capacity. Eidolon/Goddess support affects running cost; Lord of Wars applies
the native twenty-percent attack contribution to self. Hope can restore the
single local hero. Zyphyrus grants self movement/basic attack speed with no
active refresh. Exposure and Chaos have explicit offline defense/damage and
wandering behavior. Party targets are not simulated or represented as connected
players. Source requirements above the currently recovered honor caps stay gated.

Monster poison uses the native Spirit/30 duration path, a one-second tick and
`max(1, 2*floor(maxHP/100))` direct HP damage. Armor and mana shields do not absorb
it; Scarecrow, cleansing and impairment prevention remain effective. Duration is
limited to six seconds for offline play, as with other admitted impairments.
Native probability and the complete status interaction pipeline remain partial.

## Presentation and data completeness

Original RMD primary/secondary attack sequences are decoded incrementally for
44 actor appearances (88 groups), including all nine heroes. Empty/unknown pose
semantics are not invented. Actor action timing uses offline input pacing.
The old generic attack arc is suppressed when original attack art is available.
NPC rendering now shares the same stable separated anchors as hit testing.
Readable map items open a walkability/NPC overview without being consumed.
Resource bars and Walk/Run are touch-accessible; long action names remain inside
their controls. The launcher uses the original supplied client icon.

All 48 music tracks remain packaged for offline playback. The RMA 6-to-7 update
archive was acquired, hashed and compared: all nine resource files already match
the full client, and it supplies none of the 18 missing object RMD references.
The additional GameZone 4.402 acquisition attempt returned HTTP 503.
