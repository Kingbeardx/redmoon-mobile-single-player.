import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from honor_rules import honor_after_kill
class Honor(unittest.TestCase):
 def test_neutral_creatures(self):
  for h in [-100,-1,0,1,100]:self.assertEqual(honor_after_kill(h,0),h)
 def test_opposite_alignment(self):self.assertEqual(honor_after_kill(0,-1),1);self.assertEqual(honor_after_kill(0,1),-1)
 def test_step_boundaries(self):
  for rep,want in [(1,-1),(100,-1),(101,-2),(300,-3),(900,-9),(1000,-10),(1001,-10),(-101,2)]:self.assertEqual(honor_after_kill(0,rep),want)
 def test_no_crossing_zero(self):self.assertEqual(honor_after_kill(5,900),0);self.assertEqual(honor_after_kill(-5,-900),0)
 def test_initial_caps(self):self.assertEqual(honor_after_kill(99,-300),100);self.assertEqual(honor_after_kill(-99,300),-100)
 def test_preserve_existing_higher_honor(self):self.assertEqual(honor_after_kill(550,-300),550);self.assertEqual(honor_after_kill(-550,300),-550)
 def test_quest_cap_parameter(self):self.assertEqual(honor_after_kill(150,-300,200),153)
 def test_input_validation(self):
  with self.assertRaises(ValueError):honor_after_kill(0,1,0)
 def test_x86_reciprocal_division(self):
  # GetMopFame uses signed IMUL 0x51eb851f, SAR 5 and sign correction.
  for value in range(-2000,2001):
   if value==0:continue
   input_value=value-1 if value>0 else value+1
   high=(input_value*0x51eb851f)>>32
   quotient=(high>>5)+((high & 0xffffffff)>>31)
   step=quotient+(1 if value>0 else -1)
   step=max(-10,min(10,step))
   self.assertEqual(honor_after_kill(0,value),-step)
if __name__=='__main__':unittest.main()
