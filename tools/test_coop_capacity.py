"""Verify a real four-player ENet session with isolated host and guest processes."""
from pathlib import Path
import os,subprocess,tempfile,time
ROOT=Path(__file__).resolve().parents[1]
GODOT=os.environ.get('GODOT','/workspace/scratch/godot/Godot_v4.5.1-stable_linux.x86_64')
def run():
    running=[]
    try:
        for role in ['host','Peer0','Peer1','Peer2']:
            path=ROOT/f'analysis/v18-capacity-{role}.log';f=path.open('w')
            args=[GODOT,'--headless','--path',str(ROOT/'game'),'--audio-driver','Dummy','--script','res://tests/coop_capacity.gd','--',role]
            p=subprocess.Popen(args,env=dict(os.environ,XDG_DATA_HOME=tempfile.mkdtemp(prefix='rm-capacity-')),stdout=f,stderr=subprocess.STDOUT);running.append((p,f,path))
            if role=='host':time.sleep(.5)
        for p,f,path in running:
            p.wait(timeout=20);f.close();text=path.read_text();print('\n'.join(line for line in text.splitlines() if 'checks' in line or 'ERROR' in line))
            assert p.returncode==0 and 'ERROR' not in text,path
    finally:
        for p,f,_ in running:
            if p.poll() is None:p.kill();p.wait()
            f.close()
if __name__=='__main__':run()
