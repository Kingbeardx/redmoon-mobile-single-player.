"""Import inventory icons by item category and source image index."""
from pathlib import Path
import argparse,json
from client_assets import Converter
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('client',type=Path);a=p.parse_args();game=Path('game');path=game/'data/client-art.json';art=json.loads(path.read_text());items=json.loads((game/'data/item-metadata.json').read_text());c=Converter(a.client,game/'art');c.meta=art['images'];icons={};issues=[]
 for key,item in items['items'].items():
  try:icons[key]=c.compose('Ico',int(key.split(':')[0]),item['image'])
  except (KeyError,ValueError,IndexError) as e:issues.append({'item':key,'reason':str(e)})
 art['images']=c.meta;art['item_icons']=icons;art['item_icon_issues']=issues;path.write_text(json.dumps(art,separators=(',',':')));print('Item icons:',len(icons),'unresolved:',len(issues))
