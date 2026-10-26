import unittest,tempfile,json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from pack_art import pack
class PackTests(unittest.TestCase):
 def test_identical_payloads_preserve_offsets_and_are_reversible(self):
  with tempfile.TemporaryDirectory() as directory:
   root=Path(directory);game=root/'game';(game/'art').mkdir(parents=True);(game/'data').mkdir()
   original={'images':{'a':[1,2,3,4],'b':[-5,-6,3,4]},'actors':{}}
   (game/'data/client-art.json').write_text(json.dumps(original))
   for key in ['a','b','unused']:(game/'art'/(key+'.pngdata')).write_bytes(b'identical bytes')
   pack(game,root/'archive')
   result=json.loads((game/'data/client-art.json').read_text())
   self.assertEqual(result['images']['b'][:4],[-5,-6,3,4])
   self.assertEqual(result['images']['a'][4],result['images']['b'][4])
   self.assertTrue((root/'archive/b.pngdata').exists())
   self.assertEqual(len(list((game/'art').glob('*'))),1)
   pack(game,root/'archive')
   self.assertEqual(json.loads((game/'data/client-art.json').read_text()),result)
