# Honor from original monster reputation

Source: `CMapServerClient::GetMopFame`, VA 0x439a10, in the supplied 3.8 server.
The original monster-death handler calls it at 0x4790ed with the MOPINFO reputation
field. No legacy executable was run. `tools/skill_evidence.py` saves disassembly
and hashes to the ignored analysis directory; `tools/honor_rules.py` is the
independent arithmetic reference.

Neutral creatures give no change. For nonzero reputation R, the signed step is
`sign(R) * min(10, ceil(abs(R) / 100))`; it moves player honor in the opposite
direction. At neutral honor the result is minus that step. Changing an existing
alignment toward neutral stops at zero and cannot cross it in the same kill.
Moving farther from neutral is capped, without reducing already-higher honor.

The ordinary initial cap is ±100. Quest flag bits 0x2, 0x8, 0x40, 0x400 and
0x2000 raise successive caps to 200, 300, 400, 500 and 1000 in the original
routine. Those quest flags/rewards are not restored, and there is no invented
level-based increase or manual alignment chooser. Arena/special-state cap rules
are outside this offline implementation. Existing higher-honor saves are kept.

The bounded spawn sampler now retains both original factions when a map's source
spawns contain them. Coordinates, IDs and respawn intervals still come from the
source. Legacy neutral-only populations receive missing faction samples once;
existing dead faction creatures retain their timers. Creature labels show the
actual prospective honor change, including zero-crossing/cap effects. JOURNEY
shows honor and the cap. The neutral training journey is otherwise unchanged.

Python tests check signed boundaries, neutral crossing, caps and the original
signed reciprocal IMUL/SAR division over 4,000 nonzero inputs. Godot tests cover
combat rewards, no duplicate rewards, legacy population repair and UI unlocking.
