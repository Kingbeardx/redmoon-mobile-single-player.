"""Save bounded, static evidence from the original server's named functions."""
from pathlib import Path
import argparse,json,hashlib
import pefile,capstone
from inspect_pe import coff_symbols
from skill_import import build
ROOT=Path(__file__).resolve().parents[1]
NAMES=('?CheckSkillRequirement@','?DecreaseMP@','?UseSkillAlone@','?UseSkillUserCure@','?Serialize@CrSkillInfo@','?GetSkillAttack@','?GetMopFame@','?IncreaseAbsFame@','?UseSkillAttackSingleMop@','?Dead@CMopServer@','?DoSkillEffect@CMapServerClient@','?UseSkill@CMopServer@','?UseSkillRange@CMopServer@','?UseSkillRangeEffect@CMopServer@')
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("client",type=Path);args=parser.parse_args()
 path=ROOT/'originals/1-RedMoonServe-RaGEZONE-/Bin/svMapServer.exe';raw=path.read_bytes();pe=pefile.PE(data=raw)
 symbols=coff_symbols(pe,raw);functions=sorted((s for s in symbols if s['type']==32 and s.get('section')==1),key=lambda s:s['rva']);names={s['va']:s['name'] for s in functions};md=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_32);evidence=[];assembly=[]
 for s in functions:
  if not s['name'].startswith(NAMES):continue
  end=next(t['rva'] for t in functions if t['rva']>s['rva']);evidence.append({'symbol':s['name'],'va':hex(s['va']),'bytes':end-s['rva']});assembly.append('; '+s['name'])
  for i in md.disasm(pe.get_data(s['rva'],end-s['rva']),s['va']):
   target=int(i.op_str,16) if i.mnemonic=='call' and i.op_str.startswith('0x') else 0
   assembly.append(f'{i.address:08x} {i.mnemonic:8s} {i.op_str}'+(' ; '+names[target] if target in names else ''))
 data=build(ROOT/'originals/2-RedMoon38Fixed-RaGEZONE-/Bin/Data/Skill/skill00.rmi',args.client)
 report={'server_sha256':hashlib.sha256(raw).hexdigest(),'execution':'static parsing and disassembly only','functions':evidence,'catalog':data['summary'],'client_differing_player_records':sum(bool(r['client_differences']) for r in data['skills']),'unresolved':'44 skills; special DP, honor cap quests, full base attack/status pipeline, PvP, ally-targeting and advanced effects. Offline cooldown 0.8 seconds is not an original server constant.'}
 (ROOT/'analysis/skills-evidence.json').write_text(json.dumps(report,indent=2)+'\n');(ROOT/'analysis/skills-evidence.asm').write_text('\n'.join(assembly)+'\n');print(json.dumps({k:v for k,v in report.items() if k not in ('functions','server_sha256')}))
if __name__=='__main__':main()
