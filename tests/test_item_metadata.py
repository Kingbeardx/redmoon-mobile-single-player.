import unittest,sys,struct,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from item_metadata import decode_stats,FormatError
class ItemMetadataTests(unittest.TestCase):
 def test_fixed_layout_and_unsigned_fields(self):
  values=list(range(1,15))+[204,65535,0,7,0]+[0,8,2,90]+[4000000001]
  raw=struct.pack('<14I5H4BI',*values)
  result=decode_stats(raw)
  self.assertEqual(result['hp'],1)
  self.assertEqual(result['required_level'],9)
  self.assertEqual(result['weight'],65535)
  self.assertEqual(result['range'],8)
  self.assertEqual(result['price'],4000000001)
 def test_rejects_incomplete_or_extra_fields(self):
  for n in [0,73,75]:
   with self.assertRaises(FormatError):decode_stats(bytes(n))
 @unittest.skipUnless((ROOT/'game/data/item-metadata.json').exists(),'generated corpus missing')
 def test_reference_items_and_localization(self):
  data=json.loads((ROOT/'game/data/item-metadata.json').read_text())
  self.assertEqual(len(data['items']),784)
  self.assertEqual(data['items']['1:1']['name'],'Oak Sword')
  self.assertEqual(data['items']['1:1']['attack'],5)
  self.assertEqual(data['items']['1:1']['price'],50)
  self.assertEqual(data['items']['4:1']['hp'],1000)
  self.assertEqual(data['items']['4:3']['price'],600)
