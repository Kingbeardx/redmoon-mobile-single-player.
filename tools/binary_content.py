#!/usr/bin/env python3
"""Lossless structural decoder for the supplied RedMoon RSI and RMI tables.

This recovers strings and record boundaries, not the meanings of opaque stats.
It never loads or executes game code. See docs/binary-content.md for evidence.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct

ITEM_HEADER = "RedMoon ItemInfo File 1.0"
SKILL_HEADER = "RedMoon Skill Info File V 1.0"
ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "originals/2-RedMoon38Fixed-RaGEZONE-/Bin/Data"


class FormatError(ValueError):
    """Unexpected or truncated input; no partial table is returned."""


class Reader:
    def __init__(self, data: bytes):
        self.data = data
        self.pos = 0

    def take(self, count: int) -> bytes:
        if count < 0 or count > len(self.data) - self.pos:
            raise FormatError(f"Truncated field at offset {self.pos}: need {count} bytes")
        result = self.data[self.pos:self.pos + count]
        self.pos += count
        return result

    def u32(self) -> int:
        return struct.unpack("<I", self.take(4))[0]

    def string(self) -> dict:
        """Read the MFC-style ANSI length form used by the supplied tables."""
        start = self.pos
        length = self.take(1)[0]
        if length == 0xFF:
            length = struct.unpack("<H", self.take(2))[0]
            if length == 0xFFFE:
                raise FormatError(f"Unicode CString marker unsupported at offset {start}")
            if length == 0xFFFF:
                length = self.u32()
        raw = self.take(length)
        try:
            value = raw.decode("cp949")
        except UnicodeDecodeError as error:
            raise FormatError(f"Invalid CP949 string at offset {start}") from error
        return {"text": value, "serialized_hex": self.data[start:self.pos].hex()}


def decode_table(data: bytes, source: str = "") -> dict:
    reader = Reader(data)
    header = reader.string()
    if header["text"] == ITEM_HEADER:
        kind = "items"
        category = reader.u32()
        maximum_slot = reader.u32()
        count = maximum_slot + 1
        prefix_size, suffix_size = 8, 74
    elif header["text"] == SKILL_HEADER:
        kind = "skills"
        category = maximum_slot = None
        count = reader.u32()
        prefix_size, suffix_size = 1, 38
    else:
        raise FormatError(f"Unsupported table header {header['text']!r}")
    minimum_record_size = prefix_size + suffix_size + 2
    if count > (len(data) - reader.pos) // minimum_record_size:
        raise FormatError(f"Declared {count} records exceed remaining file size")
    header_size = reader.pos
    records = []
    for slot in range(count):
        start = reader.pos
        prefix = reader.take(prefix_size)
        first, second = reader.string(), reader.string()
        name, description = (first, second) if kind == "items" else (second, first)
        suffix = reader.take(suffix_size)
        record = {
            "slot": slot,
            "offset": start,
            "size": reader.pos - start,
            "name": name["text"],
            "description": description["text"],
            "name_serialized_hex": name["serialized_hex"],
            "description_serialized_hex": description["serialized_hex"],
            "prefix_hex": prefix.hex(),
            "suffix_hex": suffix.hex(),
        }
        if kind == "items":
            # Interpretation of these integer values is deliberately left open.
            record["prefix_u32_le"] = list(struct.unpack("<II", prefix))
        else:
            record["prefix_u8"] = prefix[0]
        records.append(record)
    if reader.pos != len(data):
        raise FormatError(f"{len(data) - reader.pos} unexplained trailing bytes at {reader.pos}")
    result = {
        "kind": kind,
        "source": source,
        "sha256": hashlib.sha256(data).hexdigest(),
        "bytes": len(data),
        "header": header["text"],
        "header_hex": data[:header_size].hex(),
        "category": category,
        "maximum_slot": maximum_slot,
        "record_count": count,
        "named_record_count": sum(bool(row["name"]) for row in records),
        "records": records,
    }
    if encode_table(result) != data:
        raise FormatError("Internal lossless round-trip verification failed")
    return result


def encode_table(table: dict) -> bytes:
    """Reconstruct exact original bytes using retained serialized fields.

    Human-readable name/description values are views, not editing interfaces.
    """
    output = bytearray.fromhex(table["header_hex"])
    order = ("name", "description") if table["kind"] == "items" else ("description", "name")
    for row in table["records"]:
        output.extend(bytes.fromhex(row["prefix_hex"]))
        for field in order:
            output.extend(bytes.fromhex(row[field + "_serialized_hex"]))
        output.extend(bytes.fromhex(row["suffix_hex"]))
    return bytes(output)


def build_catalog(source: Path) -> dict:
    paths = sorted((source / "Item/Info").glob("*.rsi"))
    paths += sorted((source / "Skill").glob("*.rmi"))
    if not paths:
        raise FormatError(f"No RSI/RMI tables found in {source}")
    tables = [decode_table(path.read_bytes(), path.relative_to(source).as_posix()) for path in paths]
    return {
        "schema_version": 1,
        "source_archive": "2-RedMoon38Fixed-RaGEZONE-.rar" if source.resolve() == DEFAULT_SOURCE.resolve() else None,
        "status": "Complete byte framing and CP949 strings; opaque numeric meanings not recovered",
        "tables": tables,
        "summary": {
            kind: {
                "files": sum(t["kind"] == kind for t in tables),
                "slots": sum(t["record_count"] for t in tables if t["kind"] == kind),
                "named_slots": sum(t["named_record_count"] for t in tables if t["kind"] == kind),
            }
            for kind in ("items", "skills")
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--out", type=Path, default=ROOT / "data/binary-content.json")
    args = parser.parse_args()
    result = build_catalog(args.source)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result["summary"], indent=2))


if __name__ == "__main__":
    main()
