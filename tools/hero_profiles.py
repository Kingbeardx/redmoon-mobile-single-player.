"""Recover the original English character stories and equipment hints from CTF."""
from pathlib import Path
import argparse,json,re
from item_metadata import messages
p=argparse.ArgumentParser();p.add_argument('client',type=Path);a=p.parse_args();text,_=messages((a.client/'DATAs/Info/Message.ctf').read_bytes())
items=json.loads(Path('game/data/item-metadata.json').read_text())['items'];profiles={}
for ident in range(9):
 name=text[f'0:5:{ident}'];bio=next(v for v in text.values() if v.lstrip().startswith('- '+name+'\\n')).replace('\\n','\n')
 story,_,ratings=bio.partition('Strength');weapon=re.search(r'Weapon\s+(.+)',ratings)
 weapons=[v['name'] for k,v in items.items() if k.startswith('1:') and int(v.get('characters',0))&(1<<ident)]
 profiles[str(ident)]={'name':name,'story':story.strip().split('\n',1)[1].strip(),'weapon_hint':weapon.group(1).strip() if weapon else 'See item requirements','weapon_examples':weapons[:6],'has_physical_weapons':bool(weapons),'source':'Message.ctf: 0:5:'+str(ident)}
Path('game/data/hero-profiles.json').write_text(json.dumps({'schema_version':1,'profiles':profiles},ensure_ascii=False,indent=2)+'\n');print('Recovered profiles',len(profiles))
