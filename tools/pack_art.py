"""Deduplicate identical encoded images while retaining each sprite's offsets.
Unreferenced payloads are moved outside the game, never discarded.
"""
from pathlib import Path
import hashlib,json,argparse,shutil

def pack(game,archive):
 p=game/'data/client-art.json';art=json.loads(p.read_text());seen={};keep=set();before=0
 for key,box in art['images'].items():
  source=game/'art'/((box[4] if len(box)>4 else key)+'.pngdata');data=source.read_bytes();before+=len(data);digest=hashlib.sha256(data).digest()
  if digest not in seen:seen[digest]=source.stem
  canonical=seen[digest];keep.add(canonical);art['images'][key]=box[:4]+[canonical]
 p.write_text(json.dumps(art,separators=(',',':')))
 archive.mkdir(parents=True,exist_ok=True);moved=0
 for source in (game/'art').glob('*.pngdata'):
  if source.stem not in keep:shutil.move(source,archive/source.name);moved+=1
 total=sum((game/'art'/(key+'.pngdata')).stat().st_size for key in keep)
 print(json.dumps({'sprite_entries':len(art['images']),'unique_payloads':len(keep),'logical_bytes_before':before,'payload_bytes_after':total,'quarantined_files':moved}))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--game',type=Path,default=Path('game'));p.add_argument('--archive',type=Path,required=True);a=p.parse_args();pack(a.game,a.archive)
