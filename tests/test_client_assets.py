import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from client_assets import Converter,Reader
class ClientAssetTests(unittest.TestCase):
 def test_truncated_stream(self):
  with self.assertRaises(ValueError):Reader(b'\x04abc').s()
 @unittest.skipUnless(Path('/workspace/scratch/client/Redmoon').exists(),'reference client unavailable')
 def test_sparse_list_and_actual_pixels(self):
  c=Converter(Path('/workspace/scratch/client/Redmoon'),Path('/tmp/redmoon-asset-test'))
  self.assertEqual(c.lst('tle')[0],(0,0))
  image,_,_=c.sprite('tle',0)
  self.assertGreater(image.width,0)
  self.assertGreater(image.getchannel('A').getextrema()[1],0)
  self.assertEqual(c.lst('Chr/c00')[0],(0,0))
if __name__=='__main__':unittest.main()
