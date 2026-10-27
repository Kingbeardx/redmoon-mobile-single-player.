"""Recover original event framing and the evidenced first story chapter.

No general script execution. Forty-three server slots are explicitly Removed;
the playable interaction glue is reconstructed, not a verbatim script restore.
"""
from pathlib import Path
import argparse,hashlib,json,struct
from binary_content import Reader,FormatError
from item_metadata import messages

HEADER='RedMoon EventInfo File 1.0'

def decode_events(raw):
    r=Reader(raw);header=r.string();count=r.u32()
    if header['text']!=HEADER or count>10000:raise FormatError('Invalid event header/count')
    head=raw[:r.pos].hex();events=[]
    for slot in range(count):
        map_hint=struct.unpack('<H',r.take(2))[0];unknown=r.u32();steps=r.u32()
        if steps>10000:raise FormatError('Invalid step count')
        rows=[]
        for _ in range(steps):
            flag=r.u32();condition,client,server=(r.string() for _ in range(3))
            rows.append({'server_check':flag,'condition':condition,'client_action':client,'server_action':server})
        events.append({'slot':slot,'map_hint':map_hint,'unknown_u32':unknown,'steps':rows})
    if r.pos!=len(raw):raise FormatError('Unexplained event tail')
    result={'header_hex':head,'sha256':hashlib.sha256(raw).hexdigest(),'events':events}
    if encode_events(result)!=raw:raise FormatError('Event round trip failed')
    return result

def encode_events(table):
    out=bytearray.fromhex(table['header_hex'])
    for event in table['events']:
        out.extend(struct.pack('<HII',event['map_hint'],event['unknown_u32'],len(event['steps'])))
        for step in event['steps']:
            out.extend(struct.pack('<I',step['server_check']))
            for key in ['condition','client_action','server_action']:out.extend(bytes.fromhex(step[key]['serialized_hex']))
    return bytes(out)

def event_kinds(path):
    result={}
    for line in path.read_text(encoding='cp949').splitlines():
        tokens=line.split(';',1)[0].split()
        if tokens:
            values=[int(t) for t in tokens];result[values[0]]={'kind':values[1],'args':values[2:]}
    return result

def build(client,server,game):
    script=decode_events((server/'Event/EventScript.res').read_bytes());text,_=messages((client/'DATAs/Info/Message.ctf').read_bytes())
    needed=list(range(181,236));localized={str(i):text[f'0:7:{i}'].replace('\\\\n','\n').replace('\\n','\n') for i in needed}
    content=json.loads((game/'data/content.json').read_text());kinds=event_kinds(server/'Event/EventInfo.rse');npcs=[]
    for npc in content['npcs']:
        kind=kinds.get(int(npc['event_id']),{}).get('kind',0)
        if kind in [27,28,29]:npcs.append({**npc,'story_role':{27:'archeologist',28:'geographer',29:'kasham'}[kind]})
    removed=[e['slot'] for e in script['events'] if e['steps'] and e['steps'][0]['condition']['text']=='Removed']
    return {'schema_version':1,'script_sha256':script['sha256'],'script_slots':len(script['events']),
            'removed_script_slots':removed,'messages':localized,'npcs':npcs,
            'requirements':{'minimum_level':50,'spy':{'map':74,'monster':90,'item':'5:1'},
                            'esper':{'map':72,'monster':92}},
            'honor_caps':[{'flag':2,'cap':200},{'flag':8,'cap':300},{'flag':64,'cap':400}],
            'status':'Original text, targets, NPC roles and native flags; missing script glue reconstructed. Quest XP formulas and later chapters not restored.'}

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('client',type=Path)
    p.add_argument('--server',type=Path,default=Path('originals/2-RedMoon38Fixed-RaGEZONE-/Bin/Data'))
    p.add_argument('--game',type=Path,default=Path('game'));a=p.parse_args();data=build(a.client,a.server,a.game)
    (a.game/'data/story.json').write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')))
    print(json.dumps({'script_slots':data['script_slots'],'removed_slots':len(data['removed_script_slots']),'story_npcs':len(data['npcs'])}))
