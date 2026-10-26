"""Recover client event rectangles without interpreting unsupported event types."""
import argparse,json,struct
from pathlib import Path
from client_assets import Reader

def extract(root):
 result={}
 for p in sorted((root/'DATAs/Map').glob('*.rmm')):
  r=Reader(p.read_bytes())
  if r.s()!=b'RedMoon MapData 1.0':continue
  r.ints(2);r.s();id,n=r.ints(2)
  if not 0<=n<=100000:raise ValueError('event count')
  result[str(id)]=[dict(zip(['id','left','top','right','bottom'],struct.unpack('<HIIII',r.take(18)))) for _ in range(n)]
 return result
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('client',type=Path);a=p.parse_args()
 result=extract(a.client);Path('game/data/client-events.json').write_text(json.dumps(result,separators=(',',':')))
 print('Read events for',len(result),'maps')
