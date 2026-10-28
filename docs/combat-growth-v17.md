# Attack growth restoration v0.17

Strength now increases basic attacks and weapon-based skills. The stat screen
previews attack power before applying points. Existing source class growth,
gear contributions and Berserker's attack multiplier continue to apply.

The pure Strength component is recovered from `InitializeAttack` at 0x4348c0:

- Below 1000: `8 - trunc(Strength * -0.28)`.
- Through 10000: `10 + uint32((Strength/10)^3)/3500`.
- Below 13000: `10 + uint32((Strength/100)*(Strength/10)^2)/350`.
- From 13000: `uint32(145*Strength - 0x132f3c)`.

Every integer division truncates. Wrapped intermediate products are retained.
Runtime bounds protect against pathological saves. Source disassembly is retained
in analysis/v16-native/004348c0.asm; no legacy program was executed.

Integration is an offline adaptation: existing level/weapon base plus the source
Strength component above its starting-Strength value. Psychic and DP skills keep
their existing formulas. This does not claim complete original attack, hit,
armor or monster health behavior. The large source monster HP values remain
disabled until the corresponding full combat system can be restored coherently.

Six player entries, later story scripts, twelve monster effects and multiplayer
remain unfinished. See recovery-status.md for missing input candidates. This
update fixes a functional stat-growth gap; it does not finish the original game.
