import importlib.util
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("binary_content", ROOT / "tools/binary_content.py")
binary = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(binary)


class BinaryContentTests(unittest.TestCase):
    def test_real_tables_lossless(self):
        if not binary.DEFAULT_SOURCE.exists():
            self.skipTest("Original archives not extracted")
        catalog = binary.build_catalog(binary.DEFAULT_SOURCE)
        self.assertEqual(catalog["summary"]["items"], {"files": 6, "slots": 1174, "named_slots": 786})
        self.assertEqual(catalog["summary"]["skills"], {"files": 1, "slots": 382, "named_slots": 150})
        for table in catalog["tables"]:
            with self.subTest(source=table["source"]):
                self.assertEqual(binary.encode_table(table), (binary.DEFAULT_SOURCE / table["source"]).read_bytes())
                for previous, row in zip(table["records"], table["records"][1:]):
                    self.assertEqual(previous["offset"] + previous["size"], row["offset"])

    def test_item_maximum_slot_is_inclusive(self):
        header = bytes([len(binary.ITEM_HEADER)]) + binary.ITEM_HEADER.encode() + struct.pack("<II", 4, 1)
        empty_row = bytes(84)
        parsed = binary.decode_table(header + empty_row * 2)
        self.assertEqual(parsed["record_count"], 2)
        self.assertEqual([r["slot"] for r in parsed["records"]], [0, 1])

    def test_truncated_and_trailing_data_are_rejected(self):
        header = bytes([len(binary.ITEM_HEADER)]) + binary.ITEM_HEADER.encode() + struct.pack("<II", 4, 0)
        valid = header + bytes(84)
        for data in (valid[:-1], valid + b"extra", valid[:15]):
            with self.subTest(length=len(data)), self.assertRaises(binary.FormatError):
                binary.decode_table(data)

    def test_ansi_string_length_forms(self):
        for prefix in (b"\x03", b"\xff\x03\x00", b"\xff\xff\xff\x03\x00\x00\x00"):
            parsed = binary.Reader(prefix + b"abc").string()
            self.assertEqual(parsed["text"], "abc")
            self.assertEqual(bytes.fromhex(parsed["serialized_hex"]), prefix + b"abc")

    def test_invalid_text_and_unsupported_unicode_are_rejected(self):
        for raw in (b"\x01\xff", b"\xff\xfe\xff"):
            with self.subTest(raw=raw), self.assertRaises(binary.FormatError):
                binary.Reader(raw).string()

    def test_excessive_string_size_is_bounded(self):
        with self.assertRaises(binary.FormatError):
            binary.Reader(b"\xff\xff\xff\xff\xff\xff\x7f").string()


if __name__ == "__main__":
    unittest.main()
