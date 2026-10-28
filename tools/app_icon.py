"""Convert the supplied client's ICO into a mobile launcher image; no EXE runs."""
import argparse
from pathlib import Path
from PIL import Image

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('client',type=Path);p.add_argument('--game',type=Path,default=Path('game'));a=p.parse_args()
    original=Image.open(a.client/'Icon_1.ico');size=max(original.ico.sizes(),key=lambda v:v[0]*v[1])
    image=original.ico.getimage(size).convert('RGBA').resize((192,192),Image.Resampling.LANCZOS)
    target=a.game/'art/app-icon.png';target.parent.mkdir(parents=True,exist_ok=True);image.save(target)
    print('Converted original launcher icon:',size,'to 192x192')
