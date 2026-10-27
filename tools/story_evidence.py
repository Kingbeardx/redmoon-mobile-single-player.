"""Statically archive story readiness, completion and cap evidence; never execute PE."""
import argparse,hashlib,json
from pathlib import Path
import pefile,capstone
from inspect_pe import coff_symbols
from story_import import build
ROOT=Path(__file__).resolve().parents[1]
PREFIXES=('?IsSpyQuest','?IsGoGoQuest','?IsSaharaMiniMapQuest','?IsKasam1Quest','?IsEsperQuest','?IsKasam2Quest','?GetMopFame@','?IncreaseAbsFame@','?DoEventServerAction@CMapServerClient@','?Serialize@CEventProcessInfo@')
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('client',type=Path);a=p.parse_args()
 path=ROOT/'originals/1-RedMoonServe-RaGEZONE-/Bin/svMapServer.exe';raw=path.read_bytes();pe=pefile.PE(data=raw);fs=sorted((s for s in coff_symbols(pe,raw) if s['type']==32 and s.get('section')==1),key=lambda s:s['rva']);md=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_32);evidence=[];assembly=[]
 for i,s in enumerate(fs[:-1]):
  if not s['name'].startswith(PREFIXES):continue
  size=fs[i+1]['rva']-s['rva'];evidence.append({'symbol':s['name'],'va':hex(s['va']),'bytes':size});assembly.append('; '+s['name'])
  assembly.extend(f'{v.address:08x} {v.mnemonic:8s} {v.op_str}' for v in md.disasm(pe.get_data(s['rva'],size),s['va']))
 data=build(a.client,ROOT/'originals/2-RedMoon38Fixed-RaGEZONE-/Bin/Data',ROOT/'game')
 report={'server_sha256':hashlib.sha256(raw).hexdigest(),'script_sha256':data['script_sha256'],'script_slots':data['script_slots'],'removed_script_slots':data['removed_script_slots'],'native_functions':evidence,'execution':'Static disassembly and lossless data decoding only','reconstruction':'Missing interaction glue rebuilt from CTF dialogue and native guards/flags. Boss HP and guide transport are offline adaptations; original quest XP formula and later chapters are not implemented.'}
 (ROOT/'analysis/story-evidence.json').write_text(json.dumps(report,indent=2)+'\n');(ROOT/'analysis/story-evidence.asm').write_text('\n'.join(assembly)+'\n');print('Story evidence:',len(evidence),'functions;',len(data['removed_script_slots']),'explicitly removed script slots')
if __name__=='__main__':main()
