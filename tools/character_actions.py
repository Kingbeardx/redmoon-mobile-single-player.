"""Incrementally decode original primary/secondary attack pose sequences.

RMD groups 20 and 30 were visually inspected across their first/middle/last
poses. Empty or invalid rows remain absent; locomotion and packed payloads are
retained. This does not guess missing death/cast group meanings.
"""
from pathlib import Path
import argparse,json
from client_assets import Converter

def build(client,game):
    path=game/'data/client-art.json';art=json.loads(path.read_text())
    c=Converter(client,game/'art');c.meta=art['images'];issues=[];count=0
    for actor in art['actors']:
        rows,sequences=c.rmd('Chr',int(actor))
        for action,base in [('attack',20),('attack_alt',30)]:
            directions={}
            for direction in [1,2,3,4,6,7,8,9]:
                frames=[];index=base+direction
                for frame in sequences[index] if index<len(sequences) else []:
                    if not 0<=frame<len(rows):continue
                    try:frames.append(c.compose('Chr',int(actor),frame))
                    except (ValueError,IndexError,KeyError) as error:
                        issues.append({'actor':int(actor),'action':action,'row':frame,'error':str(error)})
                if frames:directions[str(direction)]=frames
            if directions:art['actor_states'].setdefault(actor,{})[action]=directions;count+=1
    art['images']=c.meta;art['action_issues']=issues
    path.write_text(json.dumps(art,separators=(',',':')))
    return {'actor_action_groups':count,'sprite_entries':len(c.meta),'invalid_action_rows':len(issues)}

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('client',type=Path);p.add_argument('--game',type=Path,default=Path('game'));a=p.parse_args()
    print(json.dumps(build(a.client,a.game)))
