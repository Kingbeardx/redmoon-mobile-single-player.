"""Recover the nine-class attribute multipliers from constructor MOVs, statically."""
from pathlib import Path
import hashlib,json
import pefile,capstone
from capstone.x86_const import X86_OP_REG,X86_OP_IMM,X86_OP_MEM

ROOT=Path(__file__).resolve().parents[1]
def recover(binary):
    raw=binary.read_bytes();pe=pefile.PE(data=raw);md=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_32);md.detail=True
    registers={};values={}
    for ins in md.disasm(pe.get_data(0x40aca8-0x400000,0x40ae8f-0x40aca8),0x40aca8):
        if ins.mnemonic!='mov' or len(ins.operands)!=2:continue
        dest,source=ins.operands
        value=source.imm if source.type==X86_OP_IMM else registers.get(ins.reg_name(source.reg)) if source.type==X86_OP_REG else None
        if dest.type==X86_OP_REG:
            if value is not None:registers[ins.reg_name(dest.reg)]=value
        elif dest.type==X86_OP_MEM and ins.reg_name(dest.mem.base)=='esi' and 0x43cc<=dest.mem.disp<=0x4458:
            if value is None:raise ValueError('Unresolved constructor assignment')
            values[dest.mem.disp]=value
    rows=[[values[0x43cc+hero*16+attribute*4] for attribute in range(4)] for hero in range(9)]
    return {'sha256':hashlib.sha256(raw).hexdigest(),'server_order':['strength','spirit','dexterity','power'],'server_class_growth':rows,'execution':'Static constructor MOV interpretation only','base_attributes':10}

if __name__=='__main__':
    report=recover(ROOT/'originals/1-RedMoonServe-RaGEZONE-/Bin/svMapServer.exe')
    (ROOT/'analysis/v15-attribute-growth.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report['server_class_growth']))
