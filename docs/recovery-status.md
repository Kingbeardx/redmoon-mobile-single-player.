# Remaining recovery inputs and implementation limits

This is a measured inventory of the supplied 3.8 server packages and RMA 7.0
client, not a claim that every original Redmoon system is finished.

## Inputs worth recovering elsewhere

1. **A complete, matching `Bin/Data/Event/EventScript.res`.** The supplied server
   resource has 84 slots, of which 43 explicitly say `Removed`. Recover an intact
   same-version event program, plus its matching `Bin/Data/Event/EventInfo.rse`,
   `Event*.rse`, `Bin/Data/Extra/Extra*.rme`, `Mop*.rsm`/`MopSpc.rsm` and quest DB
   definitions/mail templates. These are needed to restore later story, quest
   instances, timers, targets and rewards with confidence. The first chapter was
   rebuilt from native flags and dialogue; it is not the missing script itself.
2. **Matching server map data for client-only zones.** This client has 252 map
   layouts; the server archive has 196 collision maps. The 56 unmatched IDs below
   need matching server collision/event/NPC/spawn tables or verified native
   instance/template rules. Some may be special arenas or version-specific maps;
   absence alone does not prove that every one needs a separate physical file.
3. **A complete compatible client resource set.** Eighteen object RMD paths
   referenced by the current decoder are absent (listed below). Acquire the
   corresponding RMDs and their matching LST/RLE dependencies together. Some
   references may instead need correction for map-format/version differences.
   Another copy of the same RMA ZIP will not establish a fix.
4. **Complete 4.4/4.402 server/database + matching client**, if targeting that
   release rather than 3.8. Useful preservation filenames include `4.402.zip`,
   `4.4서버.rar`, `redmoonsvr44백업12월24일.zip`, `레드문DB2.zip`, and `RedMoon44.exe`.
   These are acquisition leads, not verified downloaded inputs. The tested
   GameZone 4.402 page returned HTTP 503 during this run. Do not merge unrelated
   versions blindly. No publisher-authenticated historical checksums are known.

An original JCE source release or documented server behavior would help validate
the remaining combat/instance rules, but source code is not asserted to be a
necessary file for every unimplemented effect.

## Code work, not established missing files

All 114 player entries and all 36 monster entries now have functional reconstructed
implementations. Gate, Recall, Teleport and Resurrection use actual recruited or
connected allies. A complete replacement combat model and seven-mission campaign
continuation are playable. LAN co-op uses a new authoritative ENet host, rather
than the unavailable legacy server protocol/account infrastructure.

The new effects, mission objectives, balance and multiplayer protocol are
reconstructions; source requirements/text/art and verified arithmetic are retained.
This is not proof of exact JCE behavior. Special items outside the implemented
food/gear/map/reset-pill paths may still be reference content. Original events,
loot frequencies and every publisher-era quest cannot be authenticated from these
modified packages. No unknown executable was run. iOS still needs Apple tooling.

### Player effects still reference-only

None in the recovered 114-entry catalog.

### Missing or version-mismatched object paths

- `datas/obj/obj00076.rmd`
- `datas/obj/obj00078.rmd`
- `datas/obj/obj00079.rmd`
- `datas/obj/obj00080.rmd`
- `datas/obj/obj00081.rmd`
- `datas/obj/obj00082.rmd`
- `datas/obj/obj00154.rmd`
- `datas/obj/obj00268.rmd`
- `datas/obj/obj00269.rmd`
- `datas/obj/obj00272.rmd`
- `datas/obj/obj00273.rmd`
- `datas/obj/obj00280.rmd`
- `datas/obj/obj00281.rmd`
- `datas/obj/obj00288.rmd`
- `datas/obj/obj00290.rmd`
- `datas/obj/obj00306.rmd`
- `datas/obj/obj01963.rmd`
- `datas/obj/obj01984.rmd`

### Client-only server-map candidates

```text
Bin/Data/Map/Map00180.smm
Bin/Data/Map/Map00181.smm
Bin/Data/Map/Map00182.smm
Bin/Data/Map/Map00183.smm
Bin/Data/Map/Map00184.smm
Bin/Data/Map/Map00185.smm
Bin/Data/Map/Map00186.smm
Bin/Data/Map/Map00187.smm
Bin/Data/Map/Map00188.smm
Bin/Data/Map/Map00205.smm
Bin/Data/Map/Map00206.smm
Bin/Data/Map/Map00207.smm
Bin/Data/Map/Map00208.smm
Bin/Data/Map/Map00209.smm
Bin/Data/Map/Map00210.smm
Bin/Data/Map/Map00211.smm
Bin/Data/Map/Map00212.smm
Bin/Data/Map/Map00213.smm
Bin/Data/Map/Map00214.smm
Bin/Data/Map/Map00215.smm
Bin/Data/Map/Map00216.smm
Bin/Data/Map/Map00217.smm
Bin/Data/Map/Map00218.smm
Bin/Data/Map/Map00219.smm
Bin/Data/Map/Map00220.smm
Bin/Data/Map/Map00221.smm
Bin/Data/Map/Map00222.smm
Bin/Data/Map/Map00223.smm
Bin/Data/Map/Map00224.smm
Bin/Data/Map/Map00225.smm
Bin/Data/Map/Map00226.smm
Bin/Data/Map/Map00227.smm
Bin/Data/Map/Map00228.smm
Bin/Data/Map/Map00229.smm
Bin/Data/Map/Map00230.smm
Bin/Data/Map/Map00231.smm
Bin/Data/Map/Map00232.smm
Bin/Data/Map/Map00234.smm
Bin/Data/Map/Map00300.smm
Bin/Data/Map/Map00301.smm
Bin/Data/Map/Map00302.smm
Bin/Data/Map/Map00303.smm
Bin/Data/Map/Map00305.smm
Bin/Data/Map/Map00306.smm
Bin/Data/Map/Map00307.smm
Bin/Data/Map/Map00308.smm
Bin/Data/Map/Map00309.smm
Bin/Data/Map/Map00310.smm
Bin/Data/Map/Map00311.smm
Bin/Data/Map/Map00312.smm
Bin/Data/Map/Map00313.smm
Bin/Data/Map/Map00314.smm
Bin/Data/Map/Map00315.smm
Bin/Data/Map/Map00316.smm
Bin/Data/Map/Map00401.smm
Bin/Data/Map/Map00402.smm
```

### Explicitly deleted event slots

18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 47, 48, 49, 50, 51, 53, 54, 55, 56, 57, 58, 59, 60, 61, 74, 75, 76, 77
