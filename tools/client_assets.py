"""Convert Redmoon client assets using novluno's documented RMM/RMD/LST/RLE layouts.
Reference: https://github.com/cjschneider2/novluno (public domain). No client code executed.
"""
import struct,json,hashlib,argparse
from pathlib import Path
from functools import lru_cache
import numpy as np
from PIL import Image
class Reader:
 def __init__(self,b):self.b=b;self.p=0
 def take(self,n):
  v=self.b[self.p:self.p+n];self.p+=n
  if len(v)!=n:raise ValueError('truncated')
  return v
 def ints(self,n=1):return struct.unpack('<'+'i'*n,self.take(4*n))
 def s(self):
  n=self.take(1)[0]
  if n==255:n=struct.unpack('<H',self.take(2))[0]
  return self.take(n)
class Converter:
 def __init__(self,root,out):
  self.root=root;self.out=out;out.mkdir(parents=True,exist_ok=True);self.paths={p.relative_to(root).as_posix().lower():p for p in root.rglob('*') if p.is_file()};self.meta={};self.issues=[];self.rmd_info={};self.skipped_layers=0
 def path(self,p):return self.paths[p.lower()]
 @lru_cache(None)
 def lst(self,kind):
  r=Reader(self.path('RLEs/'+kind+'.lst').read_bytes());r.s();v=r.s();_,count=r.ints(2);items={}
  for _ in range(count):
   r.s();id,file,index=r.ints(3)
   if v==b'1.2':r.ints()
   items[id]=(file,index)
  return items
 @lru_cache(128)
 def rle(self,kind,file):
  prefix=kind.split('/')[-1];folder=kind.capitalize() if '/' not in kind else 'Chr/'+prefix.upper()
  p=self.path(f'RLEs/{folder}/{prefix}{file:05d}.rle');b=p.read_bytes()
  if b[:14]!=b'Resource File\0':raise ValueError('RLE signature')
  n=struct.unpack_from('<I',b,18)[0];return b,struct.unpack_from('<'+'I'*n,b,22)
 @lru_cache(2048)
 def sprite(self,kind,index):
  file,idx=self.lst(kind)[index];b,offsets=self.rle(kind,file);off=offsets[idx]
  if not off:raise ValueError('empty sprite')
  r=Reader(b);r.p=off;length,ox,oy,w,h,*_=r.ints(9)
  if not 0<w<4096 or not 0<h<4096:raise ValueError('sprite dimensions')
  arr=np.zeros((h*w,4),dtype=np.uint8);x=y=0
  while True:
   op=r.take(1)[0]
   if op==0:break
   if op==1:
    n=r.ints()[0];v=np.frombuffer(r.take(n*2),dtype='<u2');start=y*w+x
    if start<0 or start+n>len(arr):raise ValueError('sprite bounds')
    arr[start:start+n,0]=((v>>11).astype(np.uint32)*255//31);arr[start:start+n,1]=(((v>>5)&63).astype(np.uint32)*255//63);arr[start:start+n,2]=((v&31).astype(np.uint32)*255//31);arr[start:start+n,3]=255;x+=n
   elif op==2:x+=r.ints()[0]//2
   elif op==3:y+=1
   else:raise ValueError(f'RLE opcode {op}')
  return Image.fromarray(arr.reshape(h,w,4)),ox,oy
 @lru_cache(None)
 def rmd(self,kind,num):
  r=Reader(self.path(f'DATAs/{kind}/{kind.lower()}{num:05d}.rmd').read_bytes());r.s();r.ints(3);r.s();parts,stride=r.ints(2);self.rmd_info[(kind,num)]={"parts":parts,"stride":stride};r.s();count=r.ints()[0];rows=[]
  for _ in range(count):
   layers=[]
   for j in range(r.ints()[0]):
    v=r.ints(11);ids=r.ints(v[-1]);layers.append((v,ids))
   rows.append(layers)
  animations=[]
  for _ in range(r.ints()[0]):
   n=r.ints()[0];animations.append(list(struct.unpack('<'+'h'*n,r.take(n*2))))
  return rows,animations
 def compose(self,kind,num,idx):
  key=f'{kind.lower()}_{num}_{idx}'
  if key in self.meta:return key
  rows,_=self.rmd(kind,num)
  # novluno bevy c220f430: field 6 is render_z (field 9 is a layer/blend flag).
  layers=sorted(rows[idx],key=lambda layer:layer[0][5]);parts=[]
  for v,ids in layers:
   if not ids:continue
   if v[2] <= v[0] or v[3] <= v[1]:
    self.skipped_layers+=1;continue
   lstkind=kind.lower() if kind!='Chr' else (f'Chr/c{num:02d}' if 0 <= num <= 9 else 'Chr/etc')
   im,ox,oy=self.sprite(lstkind,ids[0]);x1,y1,x2,y2=v[:4];dx,dy=v[6:8]
   if kind=='Tle':crop=im.crop((x1,y1,x2,y2)).resize((48,24));dx=dy=0
   else:
    sx,sy=x1-ox,y1-oy;ex,ey=x2-ox,y2-oy
    cx,cy=max(0,sx),max(0,sy);cex,cey=min(im.width,ex),min(im.height,ey)
    if cex<=cx or cey<=cy:continue
    crop=im.crop((cx,cy,cex,cey));dx+=cx-sx;dy+=cy-sy
    if kind=='Chr' and v[8]==2:
     crop.putalpha(crop.getchannel('A').point(lambda a:a//2))
   if crop.width and crop.height:parts.append((crop,dx,dy))
  if not parts:raise ValueError('empty row')
  left=min(x for im,x,y in parts);top=min(y for im,x,y in parts);right=max(x+im.width for im,x,y in parts);bottom=max(y+im.height for im,x,y in parts)
  if right-left>2048 or bottom-top>2048:raise ValueError('composite bounds')
  canvas=Image.new('RGBA',(right-left,bottom-top))
  for im,x,y in parts:canvas.alpha_composite(im,(x-left,y-top))
  canvas.save(self.out/(key+'.pngdata'), format='PNG');self.meta[key]=[left,top,right-left,bottom-top];return key
 def run(self,game):
  maps={};actors={};actor_states={};object_animations={}
  for p in sorted((self.root/'DATAs/Map').glob('*.rmm')):
   try:
    r=Reader(p.read_bytes());r.s();w,h=r.ints(2);r.s();id,n=r.ints(2);r.take(n*18);cells=[]
    for _ in range(w*h):
     a,b,c,d,warp,e,f,g=r.take(8);cells.append([d*2+c//128,(c%128)*8+b//32,a//4+(b%32)*64,(g<<1)+(0 if f%24==0 else 1)])
    # Generate only referenced rows; failed references remain transparent.
    for kind,j in [('Tle',0),('Obj',2)]:
     for num,idx in set((c[j],c[j+1]) for c in cells if c[j]):
      try:self.compose(kind,num,idx)
      except Exception as ex:self.issues.append(f'{kind}/{num}/{idx}: {ex}')
    maps[str(id)]={'width':w,'height':h,'cells':cells}
   except Exception as ex:self.issues.append(f'{p.name}: {ex}')
  # novluno bevy map_spawn::anim_entry_indices: base + stride * frame.
  for key in list(self.meta):
   if not key.startswith('obj_'):continue
   _,num,base=key.split('_');num=int(num);base=int(base)
   rows,animations=self.rmd('Obj',num);stride=self.rmd_info[('Obj',num)]['stride']
   frames=[]
   for frame in animations[0] if animations else []:
    index=base+stride*max(0,frame)
    if not 0<=index<len(rows):continue
    try:frames.append(self.compose('Obj',num,index))
    except (ValueError,IndexError,KeyError):pass
   if len(frames)>1:object_animations[key]=frames
  content=json.loads((game/'data/content.json').read_text());appearances=set(range(10))|{m['appearance_id'] for m in content['monsters']}|{n['image_id'] for n in content.get('npcs',[])}
  for num in sorted(appearances):
   try:
    rows,animations=self.rmd('Chr',num);states={};allkeys=[]
    for action,base in [('walk',0),('run',10),('idle',60)]:
     directions={}
     for direction in [1,2,3,4,6,7,8,9]:
      index=base+direction;keys=[]
      for frame in animations[index] if index<len(animations) else []:
       if not 0<=frame<len(rows):continue
       try:keys.append(self.compose('Chr',num,frame))
       except (ValueError,IndexError,KeyError):pass
      if keys:directions[str(direction)]=keys;allkeys.extend(keys)
     if directions:states[action]=directions
    if not allkeys:
     for frame in range(min(len(rows),8)):
      try:allkeys.append(self.compose('Chr',num,frame))
      except (ValueError,IndexError,KeyError):pass
    if allkeys:actors[str(num)]=[list(dict.fromkeys(allkeys))];actor_states[str(num)]=states
   except Exception as ex:self.issues.append(f'Chr/{num}: {ex}')
  (game/'data/client-maps.json').write_text(json.dumps(maps,separators=(',',':')))
  (game/'data/client-art.json').write_text(json.dumps({'images':self.meta,'actors':actors,'actor_states':actor_states,'object_animations':object_animations,'skipped_nonpositive_layers':self.skipped_layers,'issues':self.issues},separators=(',',':')))
  print(json.dumps({'maps':len(maps),'images':len(self.meta),'actors':len(actors),'issues':len(self.issues),'examples':self.issues[:8]}))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('client',type=Path);p.add_argument('--game',type=Path,default=Path('game'));a=p.parse_args();Converter(a.client,a.game/'art').run(a.game)
