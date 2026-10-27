"""Render client MIDI using local FluidSynth + a General MIDI soundfont, then Ogg.
The track is original client data; the soundfont is a replacement GM instrument set.
"""
import ctypes as C,argparse,subprocess
from pathlib import Path

def render(mid,font,out):
 lib=C.CDLL('libfluidsynth.so.3')
 def bind(name,args,result):
  f=getattr(lib,name);f.argtypes=args;f.restype=result;return f
 ptr=C.c_void_p;integer=C.c_int;string=C.c_char_p
 settings=bind('new_fluid_settings',[],ptr)()
 setnum=bind('fluid_settings_setnum',[ptr,string,C.c_double],integer)
 setstr=bind('fluid_settings_setstr',[ptr,string,string],integer)
 wav=out.with_suffix('.wav')
 setnum(settings,b'synth.sample-rate',22050);setnum(settings,b'synth.gain',0.4)
 setstr(settings,b'player.timing-source',b'sample');setstr(settings,b'audio.file.name',str(wav).encode());setstr(settings,b'audio.file.type',b'wav')
 synth=bind('new_fluid_synth',[ptr],ptr)(settings)
 if bind('fluid_synth_sfload',[ptr,string,integer],integer)(synth,str(font).encode(),1)<0:raise ValueError('soundfont')
 player=bind('new_fluid_player',[ptr],ptr)(synth)
 if bind('fluid_player_add',[ptr,string],integer)(player,str(mid).encode())!=0:raise ValueError('MIDI file')
 bind('fluid_player_play',[ptr],integer)(player)
 renderer=bind('new_fluid_file_renderer',[ptr],ptr)(synth)
 process=bind('fluid_file_renderer_process_block',[ptr],integer);status=bind('fluid_player_get_status',[ptr],integer)
 blocks=0
 while status(player)==1 and blocks<22050*900//64:
  if process(renderer)!=0:raise ValueError('render failure')
  blocks+=1
 bind('delete_fluid_file_renderer',[ptr],None)(renderer)
 bind('delete_fluid_player',[ptr],None)(player);bind('delete_fluid_synth',[ptr],None)(synth);bind('delete_fluid_settings',[ptr],None)(settings)
 subprocess.run(['ffmpeg','-v','error','-y','-i',str(wav),'-af','loudnorm=I=-18:TP=-1.5:LRA=11','-ar','22050','-c:a','libvorbis','-q:a','3','-f','ogg',str(out)],check=True)
 wav.unlink();print('Rendered',mid.name,'blocks',blocks,'bytes',out.stat().st_size)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('midi',type=Path);p.add_argument('--font',type=Path,default=Path('/usr/share/sounds/sf2/TimGM6mb.sf2'));a=p.parse_args();render(a.midi,a.font,Path('game/art/music.oggdata'))
