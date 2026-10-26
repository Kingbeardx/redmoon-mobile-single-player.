"""Structural and regression checks against the supplied content, without execution."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("content_import", ROOT / "tools/content_import.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ContentTests(unittest.TestCase):
    def test_count_delimited_items_and_large_count(self):
        row = MODULE.parse_spawn("Test 8 1 2 150 200 2 5 0 4000000001 4 3 20 0 7 110".split())
        self.assertEqual(row["items"], [{"kind": 5, "index": 0, "count": 4000000001},
                                        {"kind": 4, "index": 3, "count": 20}])
        self.assertEqual(row["quantity"], 7)
        self.assertEqual(row["respawn_seconds"], 110)

    def test_rejects_shifted_missing_coordinate(self):
        with self.assertRaises(ValueError):
            MODULE.parse_spawn("Test 14 5 100 150 5 1 15 1 1 55 1 1 86 1 1 42 1 1 75 1 2 1 11490".split())

    def test_rejects_missing_name_and_negative_counts(self):
        with self.assertRaises(ValueError):
            MODULE.parse_spawn("53 2 41 115 151 1 4 12 1 0 5 55".split())
        with self.assertRaises(ValueError):
            MODULE.parse_spawn("Test 1 1 1 20 20 -1 0 0 10".split())

    def test_no_eval_of_nondecimal_tokens(self):
        with self.assertRaises(ValueError):
            MODULE.integers(["__import__('os').system('false')"])
        self.assertEqual(MODULE.integers(["00029", "-3", "+4"]), [29, -3, 4])

    def test_event_unknown_arguments_preserved(self):
        self.assertEqual(MODULE.parse_event("12 99 4 -1 9999999999".split()),
                         {"id": 12, "type": 99, "args": [4, -1, 9999999999]})

    @unittest.skipUnless((ROOT / "originals/2-RedMoon38Fixed-RaGEZONE-/Bin/Data").is_dir(),
                         "Original archive data not present")
    def test_fixed_archive_reference_records_and_anomalies(self):
        data = MODULE.import_content(ROOT / "originals/2-RedMoon38Fixed-RaGEZONE-/Bin/Data")
        self.assertEqual(len(data["monsters"]), 499)
        first = next(m for m in data["monsters"] if m["id"] == 1)
        self.assertEqual((first["appearance_id"], first["strength"], first["experience"]), (50, 50, 80))
        area = next(s for s in data["spawns"] if s["map_id"] == 29 and s["monster_id"] == 8)
        self.assertEqual(area["bounds"], {"left": 92, "top": 1, "right": 200, "bottom": 200})
        self.assertEqual((area["quantity"], area["respawn_seconds"]), (80, 110))
        self.assertTrue(any(i.get("file") == "Mop/Mop00002.rsm" and i.get("line") == 60
                            for i in data["issues"]))
        self.assertTrue(any(d["name"] == "DefaultMopRegenOff" for d in data["directives"]))
        self.assertFalse(any(s["file"].startswith("MopT/") for s in data["sources"]))


if __name__ == "__main__":
    unittest.main()
