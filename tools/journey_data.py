"""Build named destinations from preserved Web/maps.txt and existing exit records."""
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
names={}
for line in (root/'originals/2-RedMoon38Fixed-RaGEZONE-/Web/maps.txt').read_text(encoding='cp1252').splitlines():
 key,sep,value=line.partition(':')
 if sep and key.isdecimal():names[key]=value.strip()
content=json.loads((root/'game/data/content.json').read_text());maps=json.loads((root/'game/data/maps.json').read_text())['maps'];known={int(m['id']) for m in maps}
links={}
for e in content['events']:
 args=e.get('args',[])
 if e['type']==1 and len(args)>=4 and int(e['map_id']) in known and int(args[0]) in known:
  links.setdefault(str(e['map_id']),{}).setdefault(str(args[0]),[int(args[1]),int(args[2])])
data={'map_names':names,'links':links,'source':'Preserved Web/maps.txt and parsed type-1 exit destinations','new_character_evidence':{'function':'CIPClient::ProcessNewCharacterID at 0x404a10','attributes':10,'food':{'key':'4:1','count':5},'normal_coordinates':[122,115],'normal_map_sentinel':-1,'note':'Normal map sentinel resolution is unverified. Hospital 9 is a chosen safe offline start, not a claimed publisher spawn.'}}
(root/'game/data/journey.json').write_text(json.dumps(data,separators=(',',':')))
print('Named maps',len(names),'connected maps',len(links))
