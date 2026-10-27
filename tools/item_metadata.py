"""Decode item fields/localized names from independently validated binary layouts.
Format references: rm-lib/docs/RSI.md and MessageCtf.md, commit cc1393454.
This module uses the project's existing lossless reader; no rm-lib code is copied.
"""
import argparse,json,struct,hashlib
from pathlib import Path
from binary_content import Reader,decode_table,FormatError

FIELDS='hp mp attack defense strength spirit dexterity power required_level required_strength required_spirit required_dexterity required_power unknown_0 characters weight unknown_1 slot unknown_2 formula range scatter_range animation price'.split()

def decode_stats(raw):
 if len(raw)!=74:raise FormatError('item stats must be exactly 74 bytes')
 return dict(zip(FIELDS,struct.unpack('<14I5H4BI',raw)))

def messages(raw):
 r=Reader(raw)
 if r.string()['text']!='J.C.TypeConvTool Ver 1.1.2':raise FormatError('CTF header')
 count=r.u32();result={}
 if count>100000:raise FormatError('CTF message count')
 for _ in range(count):
  r.string();category,sub,id=r.u32(),r.u32(),r.u32();result[f'{category}:{sub}:{id}']=r.string()['text']
 categories=r.u32()+1
 if categories>1000:raise FormatError('CTF category count')
 for _ in range(categories):
  r.string();subcategories=r.u32()+1
  if subcategories>10000:raise FormatError('CTF subcategory count')
  for _ in range(subcategories):r.string()
 # RMA's category section has an opaque trailing fragment; preserve it.
 return result,raw[r.pos:]

def build(server_tables,client):
 localized,tail=messages((client/'DATAs/Info/Message.ctf').read_bytes());client_items={}
 for path in sorted((client/'DATAs/Info').glob('Item0*.rmi')):
  table=decode_table(path.read_bytes(),str(path.name))
  for item in table['records']:
   first,second=item['name'],item['description']
   if first.isdecimal() and second.isdecimal():
    text=localized.get(f'{table["category"]+3}:{int(first)}:{int(second)}','')
    if text:client_items[f'{table["category"]}:{item["slot"]}']=text
 result={}
 for table in server_tables['tables']:
  if table['kind']!='items':continue
  for item in table['records']:
   kind,image=item['prefix_u32_le']
   if kind==0:continue
   key=f'{table["category"]}:{item["slot"]}'
   text=client_items.get(key,item['name']);name,_,description=text.partition('@')
   result[key]={'name':name,'description':description.replace('\\\\n','\n'),'server_name':item['name'],'image':image,**decode_stats(bytes.fromhex(item['suffix_hex']))}
 return {'schema_version':1,'format_reference':'https://github.com/briansteffens/rm-lib/blob/cc1393454b45f9228c5966220d818c2ed4f7b69b/docs/RSI.md','items':result,'message_count':len(localized),'ctf_opaque_tail_hex':tail.hex()}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('client',type=Path);a=p.parse_args();data=build(json.loads(Path('game/data/binary-content.json').read_text()),a.client)
 Path('game/data/item-metadata.json').write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')))
 print('Items',len(data['items']),'localized messages',data['message_count'])
 for key in ['1:1','2:1','4:1','4:3']:print(key,data['items'].get(key))
