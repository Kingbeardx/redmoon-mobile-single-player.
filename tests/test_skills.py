"""Real original tables: class mapping, requirements, provenance and MP math."""
import sys,unittest,struct,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from skill_import import build,fields,mana_cost,FormatError
ROOT=Path(__file__).resolve().parents[1]
SERVER=ROOT/'originals/2-RedMoon38Fixed-RaGEZONE-/Bin/Data/Skill/skill00.rmi'
CLIENT=Path('/workspace/scratch/client/Redmoon')
@unittest.skipUnless(SERVER.exists() and CLIENT.exists(),'Original inputs not installed')
class Skills(unittest.TestCase):
 @classmethod
 def setUpClass(cls):cls.catalog=build(SERVER,CLIENT);cls.rows={r['id']:r for r in cls.catalog['skills']}
 def test_count(self):self.assertEqual(self.catalog['summary'],{'player_skills':114,'reconstructed':114,'reference_only':0})
 def test_combat_stances(self):
  self.assertEqual(self.rows[34]['mode'],'hide');self.assertEqual(self.rows[34]['duration_spirit_divisor'],5)
  self.assertEqual(self.rows[65]['mode'],'psychic_reflect');self.assertEqual(self.rows[48]['attack_speed'],1.5)
  self.assertEqual(self.rows[312]['attack_speed'],2);self.assertIn('offline',self.rows[312]['runtime_note'])
 def test_server_unlocks_take_priority(self):
  self.assertEqual(self.rows[3]['level'],50);self.assertEqual(self.rows[3]['client_differences']['level']['client'],10)
 def test_names_match_icon_not_slot(self):self.assertEqual(self.rows[2]['name'],'Heal');self.assertEqual(self.rows[3]['name'],'Soul Sphere')
 def test_heroine_ids(self):self.assertEqual(self.rows[61]['hero'],6);self.assertEqual(self.rows[71]['hero'],7)
 def test_signed_honor(self):self.assertEqual(self.rows[8]['honor'],-250);self.assertEqual(self.rows[10]['honor'],450)
 def test_area_range(self):self.assertTrue(self.rows[12]['area']);self.assertEqual(self.rows[12]['range'],4)
 def test_weapon_requirement(self):self.assertEqual(self.rows[26]['weapon'],'sword');self.assertEqual(self.rows[51]['weapon'],'firearm');self.assertEqual(self.rows[88]['weapon'],'bow')
 def test_special_not_generic_attack(self):self.assertEqual(self.rows[91]['mode'],'danger_attack');self.assertEqual(self.rows[91]['kind'],1)
 def test_advanced_not_silently_generic(self):self.assertEqual(self.rows[29]['mode'],'energy_drain');self.assertEqual(self.rows[6]['mode'],'gate')
 def test_monster_source_records(self):
  rows={r['id']:r for r in self.catalog['monster_skills']}
  self.assertEqual(len(rows),36);self.assertEqual(sum(r['mode']!='pending' for r in rows.values()),36)
  self.assertEqual(rows[181]['mode'],'root');self.assertEqual(rows[182]['multiplier'],250)
  self.assertEqual(rows[203]['mode'],'hold_summon');self.assertEqual(rows[201]['mode'],'steal')
 def test_protection_timer_units(self):
  self.assertEqual(self.rows[22]['duration_scale'],.2);self.assertEqual(self.rows[85]['duration_spirit_divisor'],10)
  self.assertEqual(self.rows[311]['duration_scale'],1)
 def test_new_cleanse_and_decoy_modes(self):
  self.assertEqual(self.rows[73]['mode'],'cleanse');self.assertEqual(self.rows[40]['mode'],'decoy')
 def test_record_bounds(self):
  with self.assertRaises(FormatError):fields(b'\x00'*37)
 def test_mp_formula(self):
  self.assertEqual(mana_cost(1_000_000_007,51),3);self.assertEqual(mana_cost(1_000_000_015,104),15);self.assertEqual(mana_cost(25,104),25);self.assertEqual(mana_cost(1_000_000_100,104),104)
 def test_all_original_files_agree(self):
  import hashlib
  other=ROOT/'originals/1-RedMoonServe-RaGEZONE-/Bin/Data/Skill/skill00.rmi'
  self.assertEqual(hashlib.sha256(other.read_bytes()).hexdigest(),self.catalog['source_sha256'])
if __name__=='__main__':unittest.main()
