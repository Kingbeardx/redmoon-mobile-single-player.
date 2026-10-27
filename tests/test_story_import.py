import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from story_import import decode_events,encode_events,build,event_kinds,FormatError
ROOT=Path(__file__).resolve().parents[1];SERVER=ROOT/'originals/2-RedMoon38Fixed-RaGEZONE-/Bin/Data';CLIENT=Path('/workspace/scratch/client/Redmoon')
@unittest.skipUnless(SERVER.exists() and CLIENT.exists(),'Original source inputs not installed')
class Story(unittest.TestCase):
 @classmethod
 def setUpClass(cls):cls.raw=(SERVER/'Event/EventScript.res').read_bytes();cls.table=decode_events(cls.raw);cls.data=build(CLIENT,SERVER,ROOT/'game')
 def test_server_roundtrip(self):self.assertEqual(encode_events(self.table),self.raw);self.assertEqual(len(self.table['events']),84)
 def test_client_roundtrip(self):
  raw=(CLIENT/'DATAs/Info/event00.rmi').read_bytes();table=decode_events(raw);self.assertEqual(encode_events(table),raw);self.assertEqual(len(table['events']),24)
 def test_removed_scripts_are_explicit(self):self.assertEqual(len(self.data['removed_script_slots']),43);self.assertIn(18,self.data['removed_script_slots'])
 def test_both_server_archives_same_gap(self):self.assertEqual(self.raw,(ROOT/'originals/1-RedMoonServe-RaGEZONE-/Bin/Data/Event/EventScript.res').read_bytes())
 def test_speaker_and_action_fields(self):self.assertEqual(self.table['events'][0]['steps'][0]['server_action']['text'],'ChatOneByCode +Lunarena 0')
 def test_original_quiz(self):self.assertIn('Street1',self.data['messages']['192']);self.assertIn('microfilm',self.data['messages']['191'])
 def test_correct_geographer_not_shop(self):
  rows=[n for n in self.data['npcs'] if n['story_role']=='geographer'];self.assertEqual([n['map_id'] for n in rows],[29])
 def test_original_targets(self):self.assertEqual(self.data['requirements']['spy']['monster'],90);self.assertEqual(self.data['requirements']['esper'],{'map':72,'monster':92})
 def test_caps(self):self.assertEqual(self.data['honor_caps'],[{'flag':2,'cap':200},{'flag':8,'cap':300},{'flag':64,'cap':400}])
 def test_reject_truncated_or_trailing(self):
  for raw in [self.raw[:-1],self.raw+b'\x00']:
   with self.assertRaises(FormatError):decode_events(raw)
if __name__=='__main__':unittest.main()
