# Text server content

`tools/content_import.py` reads the Fixed archive's Bin/Data directory as CP949
text. It follows exact canonical filenames rather than merging alternate,
backup, poison/event, or MopT files. Each record retains source filename, source
line, and raw fields; source tables retain hashes and comments. No table content
is evaluated as code. Alternate files are explicitly listed under excluded_variants.

| Table | Imported structure | Count |
|---|---|---:|
| Mop/MopInfo.rsm | 23 numeric fields per monster | 499 |
| Mop/MopNNNNN.rsm | spawn name, ID, bounds, item triples, pattern, quantity, respawn | 2,546 |
| Event/EventNNNNN.rse | event ID, type, opaque argument list | 2,656 |
| Event/EventInfo.rse | global event records | 289 |
| Shop/ShopNNNNN.rss | item category/index, count, price percentage, unknown fifth field | 2,450 |
| Map/ShopNNNNN.rss | map-to-shop ID links | 86 |
| Extra/ExtraNNNNN.rme | NPC name, image/event IDs, rectangle, movement flag | 187 |
| Mop/MopSpc.rsm | special-drop records | 755 |

Monster field names are translations of source column comments. They include
appearance/view/speed, attack ranges and intervals, projectile and skill IDs,
Power/Spirit/Dexterity/Constitution-like stats, experience, reputation, and flags.
Those names do not establish original combat formulas or timing units.

Spawn rows use a count-delimited sequence of item category/index/count triples.
Source comments identify respawn seconds. Counts do not establish drop chances.
The importer preserves 43 DefaultMopRegenOff directives without implementing their
runtime effect. The prototype uses a bounded sample of spawn rectangles rather
than the source MMO population or respawn behavior.

The parser quarantines 67 malformed rows and retains 7 warnings, with reasons and
raw text in `issues`. Examples include missing names, missing/shifted coordinates,
extra item fields, unknown monster references, and an encoding issue. It never
guesses repairs. Fixed/Mop00001 includes an unusually high population; the mobile
prototype's deliberate population cap prevents reproducing that load.

All 100 files in the separate Mop archive already match Fixed/Mop byte for byte.
The first server archive uses older/unhandled Mop layouts: its zero imported
monster/spawn counts in the comparison report mean the current schema does not
parse those layouts, not that the source contains no monsters or spawns.

Binary .rsi items and .rmi skills are handled by `tools/binary_content.py`;
see [binary-content.md](binary-content.md). Numeric event types and script behavior
are retained as data and are not executed by the prototype.
