"""Extract named COFF function disassembly without executing a legacy binary."""
import argparse,hashlib,json
from pathlib import Path
import pefile,capstone
from inspect_pe import coff_symbols

def extract(binary: Path,output: Path,prefixes: list[str]):
    raw=binary.read_bytes();pe=pefile.PE(data=raw)
    functions=sorted((s for s in coff_symbols(pe,raw) if s['type']==32 and s.get('section')==1),key=lambda s:s['rva'])
    names={s['va']:s['name'] for s in functions}
    md=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_32);output.mkdir(parents=True,exist_ok=True)
    index=[]
    for symbol,next_symbol in zip(functions,functions[1:]):
        if not symbol['name'].startswith(tuple(prefixes)):continue
        assembly=['; '+symbol['name']]
        for instruction in md.disasm(pe.get_data(symbol['rva'],next_symbol['rva']-symbol['rva']),symbol['va']):
            target=int(instruction.op_str,16) if instruction.mnemonic=='call' and instruction.op_str.startswith('0x') else 0
            assembly.append(f'{instruction.address:08x} {instruction.mnemonic:8s} {instruction.op_str}'+(' ; '+names[target] if target in names else ''))
        file=f'{symbol["va"]:08x}.asm';(output/file).write_text('\n'.join(assembly)+'\n')
        index.append({'name':symbol['name'],'file':file,'instructions':len(assembly)-1})
    report={'sha256':hashlib.sha256(raw).hexdigest(),'execution':'static disassembly only','functions':index}
    (output/'latest-index.json').write_text(json.dumps(report,indent=2)+'\n')
    return index

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('prefixes',nargs='+');p.add_argument('--output',type=Path,default=Path('analysis/v15-native'))
    p.add_argument('--binary',type=Path,default=Path('originals/1-RedMoonServe-RaGEZONE-/Bin/svMapServer.exe'))
    a=p.parse_args();result=extract(a.binary,a.output,a.prefixes)
    print(json.dumps(result))
