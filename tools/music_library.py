"""Render the existing client MIDI library; import only conservative music metadata.
Blood Sun gameplay tables/recordings are not imported. Theme associations require
an identical MIDI in both clients, a strong melody match, and matching map sizes.
"""
from pathlib import Path
import argparse,hashlib,json,math,subprocess,concurrent.futures,xml.etree.ElementTree as ET
from client_music import render


def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def midi_files(folder):return sorted((p for p in folder.iterdir() if p.suffix.lower()==".mid"),key=lambda p:p.name.lower())

def render_one(job):
 midi,font,output=map(Path,job)
 render(midi,font,output)
 info=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','json',str(output)]))
 return {'id':midi.stem[-3:],'name':'Redmoon Track '+midi.stem[-3:],'path':'art/'+output.name,'source_sha256':digest(midi),'duration':float(info['format']['duration'])}

def main():
 p=argparse.ArgumentParser();p.add_argument('client',type=Path);p.add_argument('--blood-sun',type=Path);p.add_argument('--matches',type=Path);p.add_argument('--font',type=Path,default=Path('/usr/share/sounds/sf2/TimGM6mb.sf2'));a=p.parse_args()
 out=Path('game/art');out.mkdir(parents=True,exist_ok=True);manifest=Path('game/data/music.json');cache=json.loads(manifest.read_text()) if manifest.exists() else {};previous={t['id']:t for t in cache.get('tracks',[])};font_hash=digest(a.font)
 jobs=[];tracks=[]
 for midi in midi_files(a.client/'RLEs/Mid'):
  key=midi.stem[-3:];target=out/f'music_{key}.oggdata';old=previous.get(key,{})
  if target.exists() and old.get('source_sha256')==digest(midi) and cache.get('soundfont_sha256')==font_hash and cache.get('render_version')==2:
   old=dict(old);old["name"]="Redmoon Track "+key;tracks.append(old)
  else:jobs.append((str(midi),str(a.font),str(target)))
 with concurrent.futures.ProcessPoolExecutor(max_workers=2) as pool:
  for track in pool.map(render_one,jobs):tracks.append(track)
 tracks.sort(key=lambda t:t['id']);themes={};mapping={};evidence=[]
 if a.blood_sun and a.matches:
  originals={p.name.lower():p for p in midi_files(a.client/'RLEs/Mid')}
  data=json.loads(a.matches.read_text());known_maps=json.loads(Path('game/data/client-maps.json').read_text())
  for entry in data:
   first,second=entry['candidates'][:2];mid=originals.get(first['midi'].lower())
   other=a.blood_sun/first['midi'].lower()
   if not mid or not other.exists() or digest(mid)!=digest(other):continue
   if first['score']<.85 or first['score']-second['score']<.15 or first['duration_delta']>3:continue
   name=Path(entry['wma']).stem;themes[name]=mid.stem[-3:];evidence.append({'theme':name,'track':mid.stem[-3:],'midi_sha256':digest(mid),'melody_similarity':first['score'],'next_match_margin':round(first['score']-second['score'],4),'duration_difference_seconds':first['duration_delta']})
  # XNB custom RMM bodies start with uint16 map ID, width and height.
  import struct
  def body(path):
   b=path.read_bytes();pos=10
   def vint():
    nonlocal pos
    value=0;shift=0
    while True:
     x=b[pos];pos+=1;value|=(x&127)<<shift
     if x<128:return value
     shift+=7
     if shift>28:raise ValueError('XNB length')
   if b[:3]!=b'XNB' or b[5]&0xC0:raise ValueError('Unsupported XNB')
   for _ in range(vint()):n=vint();pos+=n+4
   if vint()!=0 or vint()!=1:raise ValueError('XNB object table')
   return struct.unpack_from('<3H',b,pos)
  for record in ET.parse(a.blood_sun/'CDataClient').getroot().iter('Component'):
   key=record.findtext('key','');theme=record.findtext('value','')
   if not key.startswith('data_music_map_') or theme not in themes:continue
   ident=key.removeprefix('data_music_map_');old=known_maps.get(ident);source=a.blood_sun/f'Map{int(ident):05}.xnb'
   if not old or not source.exists():continue
   mid,w,h=body(source)
   if mid==int(ident) and [w,h]==[old['width'],old['height']]:mapping[ident]=themes[theme]
 for t in tracks:
  for theme,ident in themes.items():
   if t['id']==ident:t['name']=theme.replace('_',' ').title()+' · Track '+ident
 result={'schema_version':1,'render_version':2,'soundfont_sha256':font_hash,'default_track':'001','tracks':tracks,'map_tracks':mapping,'theme_evidence':evidence,'note':'MIDI compositions come from the existing RMA client. Replacement GM instruments, normalized loudness. Blood Sun recordings/gameplay changes are not included; compatible theme metadata is selective.'}
 manifest.write_text(json.dumps(result,indent=2)+'\n');print('Library:',len(tracks),'tracks;',len(mapping),'map assignments;',len(evidence),'qualified themes',flush=True)
if __name__=='__main__':main()
