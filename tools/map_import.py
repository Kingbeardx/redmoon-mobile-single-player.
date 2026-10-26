#!/usr/bin/env python3
"""Decode RedMoon SMM maps without executing the legacy Windows server.

The stream layout and user occupancy bits are confirmed against CrsMap::Serialize
and CrsMap::GetCanExistUser in the supplied svMapServer.exe. See docs/map-format.md.
No graphics, original starting positions, or inter-map transitions are invented.
"""

from __future__ import annotations

import argparse
import base64
from collections import deque
import hashlib
import json
from pathlib import Path
import struct

SIGNATURE = b"RedMoon Server MapData 1.0"
MAX_CELLS = 4_000_000


class MapFormatError(ValueError):
    """A map has unsupported or inconsistent structure."""


class Reader:
    def __init__(self, data: bytes):
        self.data = data
        self.offset = 0

    def take(self, length: int) -> bytes:
        if length < 0 or self.offset + length > len(self.data):
            raise MapFormatError(f"Truncated map at byte {self.offset}")
        value = self.data[self.offset:self.offset + length]
        self.offset += length
        return value

    def u32(self) -> int:
        return struct.unpack("<I", self.take(4))[0]

    def string(self) -> bytes:
        # All supplied files use the one-byte MFC CString length representation.
        # 0xff starts an extended representation; reject rather than misparse it.
        length = self.take(1)[0]
        if length == 255:
            raise MapFormatError("Extended MFC string lengths are not supported")
        return self.take(length)


def suggest_start(walkable: list[int], width: int, height: int) -> list[int] | None:
    """Choose a central cell in the largest four-connected traversable component.

    This is a prototype convenience, not a recovered original spawn point.
    """
    seen = bytearray(len(walkable))
    largest: list[int] = []
    for origin, allowed in enumerate(walkable):
        if not allowed or seen[origin]:
            continue
        queue = deque([origin])
        seen[origin] = 1
        component = []
        while queue:
            cell = queue.popleft()
            component.append(cell)
            x, y = cell % width, cell // width
            neighbors = []
            if x > 0:
                neighbors.append(cell - 1)
            if x + 1 < width:
                neighbors.append(cell + 1)
            if y > 0:
                neighbors.append(cell - width)
            if y + 1 < height:
                neighbors.append(cell + width)
            for neighbor in neighbors:
                if walkable[neighbor] and not seen[neighbor]:
                    seen[neighbor] = 1
                    queue.append(neighbor)
        if len(component) > len(largest):
            largest = component
    if not largest:
        return None
    center_x = sum(cell % width for cell in largest) / len(largest)
    center_y = sum(cell // width for cell in largest) / len(largest)
    start = min(largest, key=lambda cell: ((cell % width - center_x) ** 2 +
                                         (cell // width - center_y) ** 2, cell))
    return [start % width, start // width]


def decode_smm(data: bytes, source: str = "") -> dict:
    reader = Reader(data)
    if reader.string() != SIGNATURE:
        raise MapFormatError("Unsupported SMM signature")
    width, height = reader.u32(), reader.u32()
    if width < 1 or height < 1 or width * height > MAX_CELLS:
        raise MapFormatError(f"Invalid or excessive dimensions {width}x{height}")
    raw_name = reader.string()
    try:
        name = raw_name.decode("cp949")
    except UnicodeDecodeError as exc:
        raise MapFormatError("Map name is not valid CP949") from exc
    map_id = reader.u32()
    cells_offset = reader.offset
    cells = reader.take(width * height * 8)
    if reader.offset != len(data):
        raise MapFormatError(f"Unexpected {len(data) - reader.offset} trailing bytes")
    modes: list[list[int]] = [[], []]
    walkable: list[int] = []
    for index in range(width * height):
        x, y = index % width, index // width
        in_bounds = 0 < x < width and 0 < y < height
        # CrsMap::CheckEnter also checks a nibble in byte 1 for each mode.
        # Those nibbles are zero in all supplied maps, but retain the exact rule.
        b1, b2, b3 = cells[index * 8 + 1:index * 8 + 4]
        mode0 = int(in_bounds and bool(b2 & 1) and not (b1 & 15))
        mode1 = int(in_bounds and bool(b3 & 1) and not (b1 >> 4))
        modes[0].append(mode0)
        modes[1].append(mode1)
        walkable.append(mode0 & mode1)
    return {
        "schema_version": 1,
        "id": map_id,
        "name": name,
        "name_encoding": "cp949",
        "width": width,
        "height": height,
        "grid_order": "row-major",
        "source": source,
        "source_sha256": hashlib.sha256(data).hexdigest(),
        "cells_offset": cells_offset,
        "cell_encoding": "two little-endian uint32 words: high word then low word",
        "raw_cells_base64": base64.b64encode(cells).decode("ascii"),
        "walkable_modes": modes,
        "walkable": walkable,
        "walkability_rule": "Intersection of CrsMap::CheckEnter for mode 0 and mode 1",
        "walkability_confidence": "static-code verified; intersection is a prototype simplification",
        "start": suggest_start(walkable, width, height),
        "start_origin": "prototype: center of largest four-connected walkable component",
        "transitions": [],
        "transitions_status": "not decoded from SMM; empty does not establish absence",
    }


def import_maps(source: Path, output: Path) -> dict:
    source = source.resolve()
    paths = sorted(source.glob("*.smm"))
    if not paths:
        raise MapFormatError(f"No SMM maps in {source}")
    # Validate the entire batch before replacing any generated map files.
    maps = []
    ids = set()
    for path in paths:
        item = decode_smm(path.read_bytes(), path.name)
        if item["id"] in ids:
            raise MapFormatError(f"Duplicate map ID {item['id']}")
        ids.add(item["id"])
        maps.append(item)
    target = output / "maps"
    target.mkdir(parents=True, exist_ok=True)
    index = {"schema_version": 1, "maps": []}
    for item in maps:
        relative = f"maps/{item['id']:05d}.json"
        (output / relative).write_text(json.dumps(item, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        row = {key: item[key] for key in ("id", "name", "width", "height", "start", "source_sha256", "walkability_confidence")}
        row["path"] = relative
        row["walkable_count"] = sum(item["walkable"])
        index["maps"].append(row)
    (output / "maps.json").write_text(json.dumps(index, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return index


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Directory containing Map*.smm")
    parser.add_argument("--output", type=Path, default=Path("data"))
    args = parser.parse_args()
    try:
        index = import_maps(args.source, args.output)
    except (MapFormatError, OSError) as exc:
        parser.exit(1, f"Map import failed: {exc}\n")
    total = sum(m["width"] * m["height"] for m in index["maps"])
    print(f"Decoded {len(index['maps'])} maps, {total:,} cells; wrote {args.output / 'maps.json'}")


if __name__ == "__main__":
    main()
