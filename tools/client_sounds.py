"""Import named PCM sound effects from the client sound list (two integers/row)."""
from pathlib import Path
import argparse,json,io,wave
from client_assets import Reader

def import_sounds(root,game):
 r=Reader((root/'RLEs/snd.lst').read_bytes());assert r.s()==b'RedMoon Lst File';assert r.s()==b'1.0';_,n=r.ints(2);table={}
 for _ in range(n):
  name=r.s().decode('cp949');id,file=r.ints(2);table[name]=(id,file)
 if r.p!=len(r.b):raise ValueError('sound-list trailing bytes')
 paths={p.name.lower():p for p in (root/'RLEs/SND').glob('*')};result={}
 for action,name in [('attack','ca-atk-1'),('heal','useitem'),('loot','coin')]:
  id,file=table[name];source=paths[f'snd{file:05d}.rms'];data=source.read_bytes()
  with wave.open(io.BytesIO(data)) as w:
   if w.getcomptype()!='NONE':raise ValueError('unsupported audio compression')
   params=w.getparams();frames=w.readframes(w.getnframes())
  cleaned=io.BytesIO()
  with wave.open(cleaned,'wb') as writer:
   writer.setparams(params);writer.writeframes(frames)
  data=cleaned.getvalue()
  (game/'art'/f'{action}.wavdata').write_bytes(data)
  result[action]={'name':name,'id':id,'file':file,'path':f'art/{action}.wavdata'}
 (game/'data/client-sounds.json').write_text(json.dumps(result))
 print('Imported named original sounds:',result)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('client',type=Path);a=p.parse_args();import_sounds(a.client,Path('game'))
