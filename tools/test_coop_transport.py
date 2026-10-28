"""Exercise actual ENet host/client processes over loopback, without an emulator."""
from pathlib import Path
import os,subprocess,tempfile,time
ROOT=Path(__file__).resolve().parents[1]
GODOT=os.environ.get('GODOT','/workspace/scratch/godot/Godot_v4.5.1-stable_linux.x86_64')
def run():
    args=[GODOT,'--headless','--path',str(ROOT/'game'),'--audio-driver','Dummy','--script','res://tests/coop_transport.gd','--']
    processes=[]
    try:
        for role in ['host','client']:
            log=ROOT/f'analysis/v18-coop-{role}.log';f=log.open('w')
            env=dict(os.environ,XDG_DATA_HOME=tempfile.mkdtemp(prefix='rm-net-'+role))
            p=subprocess.Popen(args+[role],cwd=ROOT,env=env,stdout=f,stderr=subprocess.STDOUT);processes.append((p,f,log))
            if role=='host':time.sleep(.5)
        for p,f,log in processes:
            p.wait(timeout=20);f.close();text=log.read_text()
            print('\n'.join(line for line in text.splitlines() if 'COOP ' in line or 'ERROR' in line))
            if p.returncode or 'SCRIPT ERROR' in text or 'ERROR:' in text:raise RuntimeError(f'Network scenario failed: {log}')
    finally:
        for p,f,_ in processes:
            if p.poll() is None:p.kill();p.wait()
            f.close()
if __name__=='__main__':run()
