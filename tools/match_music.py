"""Conservatively compare MIDI note/chroma timing to candidate recordings. No game code is executed."""
from pathlib import Path
import json,subprocess
import numpy as np
from scipy.signal import stft
import mido
import argparse
parser=argparse.ArgumentParser();parser.add_argument('client',type=Path);parser.add_argument('blood_sun',type=Path);parser.add_argument('--output',type=Path,default=Path('analysis/music-matches.json'));args=parser.parse_args()
old=args.client/'RLEs/Mid';new=args.blood_sun
all_midi=[p for p in old.iterdir() if p.suffix.lower()=='.mid']
duration={'midi':{p.name:mido.MidiFile(p).length for p in all_midi},'wma':{}}
for p in new.glob('*.wma'):
 duration['wma'][p.name]=float(json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','json',str(p)]))['format']['duration'])
seconds=60

def norm(x):
 x=np.maximum(x-x.mean(axis=1,keepdims=True)*.75,0)
 return x/(np.linalg.norm(x,axis=1,keepdims=True)+1e-9)

def mid_chroma(path):
 result=np.zeros((seconds,12));clock=0.;active={}
 def put(key,end):
  start,velocity=active.pop(key);pitch=key[1]%12
  for i in range(max(0,int(start)),min(seconds,int(np.ceil(end)))):
   result[i,pitch]+=max(0,min(end,i+1)-max(start,i))*velocity
 for msg in mido.MidiFile(path):
  clock+=msg.time
  if clock>seconds:
   break
  if getattr(msg,'channel',-1)==9:continue
  if msg.type=='note_on' and msg.velocity:
   key=(msg.channel,msg.note)
   if key in active:put(key,clock)
   active[key]=(clock,msg.velocity)
  elif msg.type in ['note_off','note_on']:
   key=(msg.channel,msg.note)
   if key in active:put(key,clock)
 for key in list(active):put(key,seconds)
 return norm(result)

def audio_chroma(path):
 raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-t',str(seconds),'-ac','1','-ar','11025','-f','f32le','-']);a=np.frombuffer(raw,dtype='<f4')
 freq,t,z=stft(a,fs=11025,nperseg=4096,noverlap=3072);power=np.abs(z)
 valid=(freq>=100)&(freq<=2500);freq=freq[valid];power=power[valid];pitch=69+12*np.log2(freq/440);notes=np.round(pitch).astype(int);keep=np.abs(pitch-notes)<.35
 c=np.zeros((seconds,12))
 for pc in range(12):
  energy=(power[(notes%12==pc)&keep]**.7).sum(axis=0)
  for i in range(seconds):
   window=(t>=i)&(t<i+1)
   if window.any():c[i,pc]=energy[window].mean()
 return norm(c)

mids={p.name:mid_chroma(p) for p in all_midi};results=[]
for path in sorted(new.glob('*.wma')):
 a=audio_chroma(path);rank=[]
 for name,m in mids.items():
  score=0.;shiftbest=0
  for shift in range(-4,7):
   aa=a[max(0,shift):min(seconds,seconds+shift)];mm=m[max(0,-shift):min(seconds,seconds-shift)]
   valid=(np.linalg.norm(aa,axis=1)>.1)&(np.linalg.norm(mm,axis=1)>.1)
   if valid.sum()<15:continue
   value=float(np.mean(np.sum(aa[valid]*mm[valid],axis=1)))
   if value>score:score=value;shiftbest=shift
  delta=abs(duration['wma'][path.name]-duration['midi'][name]);rank.append({'midi':name,'score':round(score,4),'shift':shiftbest,'duration_delta':round(delta,2)})
 rank.sort(key=lambda x:x['score'],reverse=True);results.append({'wma':path.name,'candidates':rank[:3]})
 print(path.name,rank[0],flush=True)
args.output.parent.mkdir(parents=True,exist_ok=True)
args.output.write_text(json.dumps(results,indent=2)+'\n')
