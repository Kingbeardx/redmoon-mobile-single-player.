# Combat stances (v0.14)

Four previously reference-only entries now run in the offline combat model:
Destino's Hide (34), Kitara's Red Halo (65), Jarexx's MadSpin (48) and Azlar's
Psychic Boost (312). Source class IDs, unlock levels, signed honor and MP costs
are unchanged. The first story chapter can raise the honor cap far enough to
reach all four entries; their original level requirements still apply.

`tools/stance_evidence.py` statically follows the original server's two switch
tables. SKILL_INFO effects 27/33/59/46 route to DoSkillEffect statuses 19/24/49/32.
The duration paths use effective Spirit divided by 5 for Hide and by 20 for the
other three, plus the source duration constant. All four status timers multiply
the result by 1000ms. No legacy executable runs. The complete original combat,
packet/animation speed and accuracy pipelines remain unreconstructed.

Offline behavior and its limits:

- Hide avoids physical HP damage while psychic attacks still hurt. It is a
  defensive stance, separate from Disguise's aggression suppression. Casting it
  again ends it; ending is free even at zero MP, whereas the native toggle pays
  MP. Root/freeze and other impairment rules continue to apply. The character
  remains visible with a translucent tint and the touch action says END HIDE.
- Red Halo returns actual psychic HP loss to its live attacking creature, after
  armor/barrier/mana-shield handling. It does not cancel that HP loss. Blocked or
  fully absorbed attacks create no reflection; overkill is capped to HP lost.
  Environmental and physical damage do not reflect. Returned damage follows the
  existing creature defeat, honor, loot and story path, with no reflection loop.
  This deterministic return amount is an offline adaptation, not a recovered
  original reflection probability/formula. A red ring marks the active stance.
- MadSpin uses source multiplier 150 as 1.5x basic attack rate; Psychic Boost
  uses an explicit offline 2x rate. Ordinary spells retain their existing recovery
  timing. Overlapping speed/reload effects use the strongest rate rather than
  multiplying. Original speed packet timing remains incomplete.

All four effects save their remaining duration with real-time expiry. Invalid
or foreign-class optional buff records continue to be rejected by the existing
save validator. The skill detail panel explains the admitted behavior.

Eidolon and Purity of Heart remain reference-only: their references to faster
special skills cannot safely be represented as faster ordinary spell cooldowns
without implementing DP. Berserker also changes Power-derived calculations in
the original server, so it is not reduced to an isolated damage multiplier.
