"""Record static original-server evidence for the admitted combat stances.

Disassembles bytes without executing them. Switch targets distinguish SKILL_INFO
effect IDs from DoSkillEffect status IDs. Numeric offline rate/reflection policy
is explicitly separate from the recovered timer paths.
"""
import hashlib,json,struct
from pathlib import Path
import pefile,capstone
from inspect_pe import coff_symbols

ROOT=Path(__file__).resolve().parents[1]
def main():
    raw=(ROOT/'originals/1-RedMoonServe-RaGEZONE-/Bin/svMapServer.exe').read_bytes()
    pe=pefile.PE(data=raw);base=pe.OPTIONAL_HEADER.ImageBase
    symbols=sorted((s for s in coff_symbols(pe,raw) if s['type']==32 and s.get('section')==1),key=lambda s:s['rva'])
    names={s['va']:s['name'] for s in symbols}
    md=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_32)
    assembly=[];functions=[]
    prefixes=('?UseSkillAlone@','?DoSkillEffect@','?InitializeAttack@','?OnPowerChanged@','?IsNormalAttackSpeed@')
    for s,t in zip(symbols,symbols[1:]):
        if not s['name'].startswith(prefixes):continue
        functions.append({'name':s['name'],'va':hex(s['va']),'bytes':t['rva']-s['rva']})
        assembly.append('; '+s['name'])
        for i in md.disasm(pe.get_data(s['rva'],t['rva']-s['rva']),s['va']):
            target=int(i.op_str,16) if i.mnemonic=='call' and i.op_str.startswith('0x') else 0
            assembly.append(f'{i.address:08x} {i.mnemonic:8s} {i.op_str}'+(' ; '+names[target] if target in names else ''))
    stances=[]
    for ident,effect,status,divisor in [(34,27,19,5),(65,33,24,20),(48,59,49,20),(312,46,32,20)]:
        index=pe.get_data(0x448518-base+effect-1,1)[0]
        target=struct.unpack('<I',pe.get_data(0x448490-base+index*4,4))[0]
        timer=struct.unpack('<I',pe.get_data(0x42ca74-base+status*4,4))[0]
        stances.append({'skill':ident,'source_effect':effect,'alone_switch_target':hex(target),'status':status,'status_switch_target':hex(timer),'spirit_divisor':divisor,'timer_ms_per_unit':1000})
    report={'server_sha256':hashlib.sha256(raw).hexdigest(),'execution':'static only','functions':functions,'stances':stances,
            'limits':'Status routes, Spirit divisors, costs and timers recovered. Offline Hide avoids physical HP damage; Red Halo returns actual psychic HP loss; Psychic Boost rate 2x and strongest-only stacking are offline policies. MadSpin uses source multiplier 150 as a 1.5x basic attack rate. Full original accuracy, defense, PvP and speed packet pipeline not reconstructed. Hide ending is free to prevent zero-MP UI lockout; original toggle charges MP.'}
    (ROOT/'analysis/v14-stance-evidence.json').write_text(json.dumps(report,indent=2)+'\n')
    (ROOT/'analysis/v14-stance-evidence.asm').write_text('\n'.join(assembly)+'\n')
    print(json.dumps({'functions':len(functions),'stance_routes':len(stances),'execution':'static only'}))
if __name__=='__main__':main()
