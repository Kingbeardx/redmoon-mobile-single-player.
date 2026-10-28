"""Generate a measured recovery gap list; distinguish absent inputs from code work."""
from pathlib import Path
import collections,hashlib,json,re

ROOT=Path(__file__).resolve().parents[1]
CLIENT=Path('/workspace/scratch/client/Redmoon')

def build(client=CLIENT,game=ROOT/'game'):
    art=json.loads((game/'data/client-art.json').read_text())
    maps=json.loads((game/'data/maps.json').read_text())['maps']
    client_maps=json.loads((game/'data/client-maps.json').read_text())
    skills=json.loads((game/'data/skills.json').read_text())
    story=json.loads((game/'data/story.json').read_text())
    paths={p.relative_to(client).as_posix().lower() for p in client.rglob('*') if p.is_file()}
    references={m.group(1).lower() for issue in art['issues'] for m in re.finditer(r"'((?:datas|rles)/[^']+)'",str(issue),re.I)}
    missing_assets=sorted(references-paths)
    missing_maps=sorted(set(map(int,client_maps))-{int(row['id']) for row in maps})
    pending=[{'id':r['id'],'name':r['name']} for r in skills['skills'] if r['mode']=='pending']
    return {'server_maps':len(maps),'client_maps':len(client_maps),
            'client_only_map_ids':missing_maps,'candidate_server_paths':[f'Bin/Data/Map/Map{n:05d}.smm' for n in missing_maps],
            'missing_asset_references':missing_assets,
            'explicitly_removed_event_slots':story['removed_script_slots'],
            'event_slots':story['script_slots'],'pending_player_effects':pending,
            'pending_monster_effects':[r['id'] for r in skills['monster_skills'] if r['mode']=='pending'],
            'asset_reference_caveat':'These paths are absent and referenced by the current RMM decoder. Version mismatches or malformed map references must be ruled out before treating every path as an independently missing required file.',
            'not_missing_files':'All 114 player and 36 monster skill records are present. Pending effects require engineering, source behavior validation or multiplayer/ally targets; another skill-tree file is not established as missing.'}

def main():
    report=build();(ROOT/'analysis/v15-recovery-inventory.json').write_text(json.dumps(report,indent=2)+'\n')
    doc='''# Remaining recovery inputs and implementation limits

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

All 114 player skill records, all 36 monster skill records, class text, equipment
tables and 48 offline music tracks are present. The remaining effects below
already have data. Exact accuracy, advanced resource theft/auras, linked monster
summons and special item effects still need native behavior integration. Gate,
Recall, ally Teleport and Resurrection need actual allies; they must not be
pretended to function in a one-character offline world. Legacy network services
also need a compatible running server/database or a replacement implementation.
No native Windows executable has been run on this host.

This build retains an explicitly approximate base combat/monster-HP/loot model.
Recovered source XP, DP, SP/recovery, requirements, durations and admitted skill
effects do not make that entire combat pipeline identical to the original.
iOS needs an Apple build/signing environment; it is not blocked on Redmoon art.

### Player effects still reference-only

'''
    doc+='\n'.join(f'- {r["id"]}: {r["name"]}' for r in report['pending_player_effects'])+'\n'
    doc+='\n### Missing or version-mismatched object paths\n\n'
    doc+='\n'.join(f'- `{p}`' for p in report['missing_asset_references'])+'\n'
    doc+='\n### Client-only server-map candidates\n\n'
    doc+='```text\n'+'\n'.join(report['candidate_server_paths'])+'\n```\n'
    doc+='\n### Explicitly deleted event slots\n\n'+', '.join(map(str,report['explicitly_removed_event_slots']))+'\n'
    (ROOT/'docs/recovery-status.md').write_text(doc)
    print(json.dumps({k:len(v) if isinstance(v,list) else v for k,v in report.items() if k in ['server_maps','client_maps','client_only_map_ids','missing_asset_references','explicitly_removed_event_slots','pending_player_effects','pending_monster_effects']}))

if __name__=='__main__':main()
