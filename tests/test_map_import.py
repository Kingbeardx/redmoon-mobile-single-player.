import base64
import importlib.util
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("map_import", ROOT / "tools/map_import.py")
MAPS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MAPS)


def fixture(width=3, height=3, cells=None):
    signature = MAPS.SIGNATURE
    name = "은행".encode("cp949")
    if cells is None:
        cells = [bytes.fromhex("00000f0f00000000")] * (width * height)
    return (bytes([len(signature)]) + signature + struct.pack("<II", width, height)
            + bytes([len(name)]) + name + struct.pack("<I", 4) + b"".join(cells))


class MapImportTests(unittest.TestCase):
    def test_verified_mode_bits_and_boundaries(self):
        cells = [bytes(8)] * 9
        cells[4] = bytes.fromhex("00000f0000000000")  # mode 0 only
        cells[5] = bytes.fromhex("0000000f00000000")  # mode 1 only
        cells[7] = bytes.fromhex("00000f0f00000000")  # both
        cells[8] = bytes.fromhex("00010f0f00000000")  # mode 0 occupancy nibble
        decoded = MAPS.decode_smm(fixture(cells=cells))
        self.assertEqual(decoded["name"], "은행")
        self.assertEqual(decoded["walkable_modes"][0], [0, 0, 0, 0, 1, 0, 0, 1, 0])
        self.assertEqual(decoded["walkable_modes"][1], [0, 0, 0, 0, 0, 1, 0, 1, 1])
        self.assertEqual(decoded["walkable"], [0, 0, 0, 0, 0, 0, 0, 1, 0])
        self.assertEqual(decoded["start"], [1, 2])
        self.assertEqual(base64.b64decode(decoded["raw_cells_base64"]), b"".join(cells))

    def test_reject_truncated_or_extra_bytes(self):
        data = fixture()
        for changed in [data[:3], data[:-1], data + b"\x00", b"\x01X" + data[2:]]:
            with self.assertRaises(MAPS.MapFormatError):
                MAPS.decode_smm(changed)

    def test_reject_excessive_dimensions(self):
        with self.assertRaises(MAPS.MapFormatError):
            MAPS.decode_smm(fixture(width=0xffffffff, height=0xffffffff, cells=[]))

    def test_start_largest_component_no_row_wrap(self):
        self.assertEqual(MAPS.suggest_start([1, 0, 1, 1, 0, 0], 3, 2), [0, 0])
        self.assertIsNone(MAPS.suggest_start([0] * 4, 2, 2))

    def test_all_supplied_maps_have_complete_valid_structure(self):
        directory = ROOT / "originals/2-RedMoon38Fixed-RaGEZONE-/Bin/Data/Map"
        if not directory.exists():
            self.skipTest("Original archives not present; synthetic coverage still applies")
        paths = sorted(directory.glob("*.smm"))
        self.assertEqual(len(paths), 196)
        cells = 0
        for path in paths:
            decoded = MAPS.decode_smm(path.read_bytes(), path.name)
            self.assertEqual(decoded["id"], int(path.stem[3:]))
            self.assertEqual(len(decoded["walkable"]), decoded["width"] * decoded["height"])
            x, y = decoded["start"]
            self.assertEqual(decoded["walkable"][y * decoded["width"] + x], 1)
            cells += decoded["width"] * decoded["height"]
        self.assertEqual(cells, 1_916_400)


if __name__ == "__main__":
    unittest.main()
