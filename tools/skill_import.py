"""Decode original skill requirements; localize by icon/class, never by slot.

Independent format implementation using the existing lossless decoder. Field
layout reference: rm-lib cc1393454 (format facts only; no code copied).
Server values take precedence over the modified RMA client. No executable runs.
"""
from pathlib import Path
import argparse, hashlib, json, struct
from binary_content import decode_table, FormatError
from item_metadata import messages

FIELDS = 'icon projectile animation honor level server_hero mana_encoded range_encoded target unused1 unused2 unused3 effect multiplier duration_base'.split()
FORMAT = '<IHIiIBIh5BII'
DAMAGE = {3,8,10,11,12,14,20,21,26,30,32,36,37,39,42,44,46,61,67,69,71,78,82,88,302,313,331,371,373}
BUFFS = {3:'disguise',4:'attack_up',5:'attack_up',6:'haste',9:'mana_shield',11:'barrier',13:'reload',14:'range_up'}
DEBUFFS = {7:'weaken',15:'root',16:'root',38:'slow'}
EXTRA_MODES = {9:'sleep',303:'sleep',86:'sleep',19:'freeze',84:'blind',
               66:'damage_blind',89:'damage_freeze',27:'leech',76:'leech',
               57:'disguise',87:'disguise',35:'fear_aura'}

def fields(raw):
    if len(raw) != 38:
        raise FormatError('Skill suffix must have 38 bytes')
    return dict(zip(FIELDS, struct.unpack(FORMAT, raw)))

def mana_cost(encoded, maximum):
    """Server DecreaseMP 0x439710: percentage is of maximum MP, truncated.
    The server treats encoded 100% specially as full MP, not floor(100%).
    """
    if encoded >= 1_000_000_000:
        percent = encoded - 1_000_000_000
        return maximum if percent >= 100 else maximum * percent // 100
    return encoded

def build(server, client):
    table = decode_table(server.read_bytes(), server.name)
    ct = decode_table((client/'DATAs/Info/skill00.rmi').read_bytes())
    text,_ = messages((client/'DATAs/Info/Message.ctf').read_bytes())
    localized = {}
    for row in ct['records']:
        if not row['name']: continue
        v = fields(bytes.fromhex(row['suffix_hex']))
        localized.setdefault((v['server_hero'],v['icon']),[]).append((row,v))
    result=[]; issues=[]
    for row in table['records']:
        if not row['name']: continue
        v=fields(bytes.fromhex(row['suffix_hex']))
        if row['prefix_u8']==2 or v['server_hero']>8: continue
        matches=localized.get((v['server_hero'],v['icon']),[])
        matches.sort(key=lambda pair:(pair[1]['effect']!=v['effect'],pair[1]['level']!=v['level']))
        if not matches: raise FormatError(f'No localized match for skill {row["slot"]}')
        cr,cv=matches[0]
        key=f'2:{cr["name"]}:{cr["description"]}'
        name,sep,description=text.get(key,'').partition('@')
        if not sep: raise FormatError(f'Missing skill message {key}')
        hero=int(cr['name'])
        if not 0<=hero<9: raise FormatError('Invalid player class reference')
        ident=row['slot']; mode='pending'; effect=v['effect']
        if row['prefix_u8']==0:
            if ident in DAMAGE: mode='damage'
            elif effect==1: mode='heal'
            elif effect in BUFFS: mode=BUFFS[effect]
            elif effect in DEBUFFS: mode=DEBUFFS[effect]
            if ident in EXTRA_MODES:mode=EXTRA_MODES[ident]
        desc=description.replace('\\\\n','\n').replace('\\n','\n')
        weapon=''
        if 'Sword Required' in desc: weapon='sword'
        elif 'Spear Required' in desc: weapon='spear'
        elif 'Bow Required' in desc or 'Bow required' in desc: weapon='bow'
        elif 'Gun or Heavy' in desc: weapon='firearm'
        elif 'Gun Required' in desc: weapon='gun'
        differing={k:{'server':v[k],'client':cv[k]} for k in FIELDS if v[k]!=cv[k]}
        result.append({'id':ident,'hero':hero,'name':name,'description':desc,
                       'kind':row['prefix_u8'],**v,'range':v['range_encoded']%10000,
                       'area':v['range_encoded']>=10000,'mode':mode,'weapon':weapon,
                       'leech_percent':30 if ident==27 else 50 if ident==76 else 0,
                       'message_key':key,'client_differences':differing,
                       'status':'reconstructed' if mode!='pending' else 'reference_only'})
        if mode=='pending': issues.append(ident)
    return {'schema_version':1,'source_sha256':hashlib.sha256(server.read_bytes()).hexdigest(),
            'client_sha256':hashlib.sha256((client/'DATAs/Info/skill00.rmi').read_bytes()).hexdigest(),
            'requirements':'Original 3.8 server; English text and displayed hero IDs from Message.ctf',
            'runtime_limit':'Damage, cooldown, targeting and status integration use the offline combat model. Honor cap quests, DP, multiplayer and advanced effects remain incomplete.',
            'skills':result,'summary':{'player_skills':len(result),'reconstructed':len(result)-len(issues),'reference_only':len(issues)}}

def icons(client,game,catalog):
    # Interface RLE entries contain normal/pressed/disabled 50x35 states stacked.
    from client_assets import Converter
    c=Converter(client,game/'art'); art_path=game/'data/client-art.json'
    art=json.loads(art_path.read_text());c.meta=art['images'];mapping={};issues=[]
    for row in catalog['skills']:
        idx=row['icon'];key=f'skill_icon_{idx}'
        try:
            if key not in c.meta:
                im,_,_=c.sprite('int',idx)
                if im.height != 105 or not 48<=im.width<=54: raise FormatError(f'Unexpected icon size {im.size}')
                im.crop((0,0,im.width,35)).save(game/'art'/(key+'.pngdata'),format='PNG')
                c.meta[key]=[0,0,im.width,35,key]
            mapping[str(row['id'])]=key
        except (KeyError,ValueError,IndexError) as e: issues.append({'id':row['id'],'error':str(e)})
    art['images']=c.meta;art['skill_icons']=mapping;art['skill_icon_issues']=issues
    art_path.write_text(json.dumps(art,separators=(',',':')))
    return {'icons':len(mapping),'issues':issues}

def projectiles(client,game,catalog):
    """Decode only referenced projectile RMD/RLE sequences, caching payloads."""
    from client_assets import Converter
    path=game/'data/client-art.json';art=json.loads(path.read_text())
    c=Converter(client,game/'art');c.meta=art['images'];mapping={};issues=[]
    for row in catalog['skills']:
        if row['mode']=='pending' or not row['projectile']:continue
        try:
            _,sequences=c.rmd('Bul',row['projectile']);directions={}
            for facing,seq_index in enumerate((1,2,3,4,6,7,8,9)):
                if seq_index>=len(sequences):continue
                frames=[]
                for index in sequences[seq_index]:
                    try:frames.append(c.compose('Bul',row['projectile'],index))
                    except ValueError as error:
                        if str(error)!='empty row':raise
                        frames.append('') # Intentional invisible animation frame.
                directions[str(facing)]=frames
            if any(any(frame for frame in seq) for seq in directions.values()):mapping[str(row['id'])]=directions
        except (KeyError,ValueError,IndexError) as e:issues.append({'id':row['id'],'error':str(e)})
    art['images']=c.meta;art['skill_projectiles']=mapping;art['skill_projectile_issues']=issues
    path.write_text(json.dumps(art,separators=(',',':')))
    return {'projectile_skills':len(mapping),'projectile_issues':issues}

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('client',type=Path)
    p.add_argument('--server',type=Path,default=Path('originals/2-RedMoon38Fixed-RaGEZONE-/Bin/Data/Skill/skill00.rmi'))
    p.add_argument('--game',type=Path,default=Path('game'));a=p.parse_args()
    result=build(a.server,a.client)
    (a.game/'data/skills.json').write_text(json.dumps(result,ensure_ascii=False,separators=(',',':')))
    print(json.dumps({**result['summary'],**icons(a.client,a.game,result),**projectiles(a.client,a.game,result)}))
