import sys,unittest,tempfile
from PIL import Image
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from client_assets import Converter,Reader
class ClientAssetTests(unittest.TestCase):
 def test_rmd_layers_use_corrected_render_depth(self):
  with tempfile.TemporaryDirectory() as directory:
   root=Path(directory);c=Converter(root,root/'output')
   def layer(depth,resource):
    return ((0,0,2,2,0,depth,0,0,99,64,1),(resource,))
   # Deliberately reversed source order: the higher layer must remain visible.
   c.rmd=lambda kind,num:([[layer(10,1),layer(0,0)]],[])
   c.sprite=lambda kind,index:(Image.new('RGBA',(2,2),'blue' if index else 'red'),0,0)
   key=c.compose('Obj',1,0)
   with Image.open(c.out/(key+'.pngdata')) as image:
    self.assertEqual(image.getpixel((0,0)),(0,0,255,255))
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
