#!/usr/bin/env python3
"""Import RedMoon's commented CP949 server tables without running legacy code.

This is a structural content importer, not an implementation of game formulas.
Unrecognized/malformed rows are retained in `issues`, never silently repaired.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re


MONSTER_FIELDS = (
    "id appearance_id view_range speed_multiplier attack_range_1 attack_range_2 "
    "attack_interval_1 attack_interval_2 projectile_id_1 projectile_id_2 "
    "skill_id_1 skill_id_2 skill_interval_1 skill_interval_2 strength spirit "
    "dexterity constitution experience attack_direction_1 attack_direction_2 "
    "reputation no_occupancy"
).split()
NUMERIC_MAP_NAME = re.compile(r"(?:Mop|Event|Extra|Shop)(\d{5})\.[a-z]+$")


def integers(tokens: list[str]) -> list[int]:
    """Decimal-only: never evaluate archive content as Python or expressions."""
    if not all(re.fullmatch(r"[+-]?\d+", t, flags=re.ASCII) for t in tokens):
        raise ValueError("non-integer field")
    return [int(t, 10) for t in tokens]


def parse_monster(tokens: list[str]) -> dict:
    if len(tokens) != len(MONSTER_FIELDS):
        raise ValueError(f"expected 23 fields, got {len(tokens)}")
    values = integers(tokens)
    return dict(zip(MONSTER_FIELDS, values))


def parse_spawn(tokens: list[str]) -> dict:
    if len(tokens) < 10:
        raise ValueError(f"expected at least 10 fields, got {len(tokens)}")
    if re.fullmatch(r"[+-]?\d+", tokens[0]):
        raise ValueError("missing non-numeric monster name; row quarantined")
    values = integers(tokens[1:])
    item_count = values[5]
    if item_count < 0:
        raise ValueError("negative item count")
    expected = 10 + 3 * item_count
    if len(tokens) != expected:
        raise ValueError(f"item count {item_count} requires {expected} fields, got {len(tokens)}")
    left, top, right, bottom = values[1:5]
    if left > right or top > bottom:
        raise ValueError("inverted spawn rectangle")
    tail = 6 + 3 * item_count
    if values[tail + 1] < 0 or values[tail + 2] < 0:
        raise ValueError("negative population or respawn time")
    return {
        "name": tokens[0], "monster_id": values[0],
        "bounds": dict(zip(("left", "top", "right", "bottom"), values[1:5])),
        "items": [dict(zip(("kind", "index", "count"), values[i:i + 3]))
                  for i in range(6, tail, 3)],
        "pattern": values[tail], "quantity": values[tail + 1],
        "respawn_seconds": values[tail + 2],
    }


def parse_event(tokens: list[str]) -> dict:
    if len(tokens) < 2:
        raise ValueError("event requires ID and type")
    values = integers(tokens)
    return {"id": values[0], "type": values[1], "args": values[2:]}


def parse_shop(tokens: list[str]) -> dict:
    if len(tokens) != 5:
        raise ValueError(f"expected 5 shop fields, got {len(tokens)}")
    values = integers(tokens)
    return {"kind": values[0], "index": values[1], "count": values[2],
            "price_percent": values[3], "unknown_field_5": values[4]}


def parse_npc(tokens: list[str]) -> dict:
    if len(tokens) != 8:
        raise ValueError(f"expected 8 NPC fields, got {len(tokens)}")
    values = integers(tokens[1:])
    return {"name": tokens[0], "image_id": values[0], "event_id": values[1],
            "bounds": dict(zip(("left", "top", "right", "bottom"), values[2:6])),
            "random_move": values[6]}


def parse_special_drop(tokens: list[str]) -> dict:
    if len(tokens) != 6:
        raise ValueError(f"expected 6 special-drop fields, got {len(tokens)}")
    values = integers(tokens[:1] + tokens[2:])
    return {"map_id": values[0], "name": tokens[1], "monster_id": values[1],
            "kind": values[2], "index": values[3], "respawn_seconds": values[4]}


def parse_map_shop(tokens: list[str]) -> dict:
    if len(tokens) != 1:
        raise ValueError("expected one shop ID")
    return {"shop_id": integers(tokens)[0]}


def import_content(data_root: Path) -> dict:
    if not (data_root / "Mop/MopInfo.rsm").is_file():
        raise ValueError(f"Expected a Bin/Data directory: {data_root}")
    result = {
        "schema_version": 1,
        "source_label": data_root.parent.parent.name,
        "selection_policy": "Exact canonical filenames only; variants and MopT are not merged.",
        "semantics": {
            "monster_fields": "Translated source column comments; no runtime formula verification.",
            "spawn_fields": "Source column comments plus count-delimited item triples; no probability inferred.",
            "event_types": "Raw numeric types and argument lists; execution semantics not implemented.",
            "shop_field_5": "Unknown; preserved verbatim. Count sentinels are not normalized.",
            "time_units": "Spawn comments specify seconds. Attack/skill interval units remain unverified.",
        },
        **{k: [] for k in ("monsters", "spawns", "events", "global_events", "event_types", "shops", "map_shops", "npcs",
                           "special_drops", "directives", "issues", "sources")},
    }
    selections = [
        ("monsters", [data_root / "Mop/MopInfo.rsm"], parse_monster),
        ("spawns", sorted((data_root / "Mop").glob("Mop[0-9][0-9][0-9][0-9][0-9].rsm")), parse_spawn),
        ("events", sorted((data_root / "Event").glob("Event[0-9][0-9][0-9][0-9][0-9].rse")), parse_event),
        ("global_events", [data_root / "Event/EventInfo.rse"], parse_event),
        ("shops", sorted((data_root / "Shop").glob("Shop[0-9][0-9][0-9][0-9][0-9].rss")), parse_shop),
        ("map_shops", sorted((data_root / "Map").glob("Shop[0-9][0-9][0-9][0-9][0-9].rss")), parse_map_shop),
        ("npcs", sorted((data_root / "Extra").glob("Extra[0-9][0-9][0-9][0-9][0-9].rme")), parse_npc),
        ("special_drops", [data_root / "Mop/MopSpc.rsm"], parse_special_drop),
    ]
    selected = set()
    for table, paths, parser in selections:
        for path in paths:
            if not path.exists():
                result["issues"].append({"severity": "error", "file": str(path.relative_to(data_root)),
                                         "reason": "required canonical table missing"})
                continue
            relative = path.relative_to(data_root).as_posix()
            selected.add(relative)
            raw = path.read_bytes()
            source = {"file": relative, "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest(),
                      "encoding": "cp949", "table": table, "comments": []}
            try:
                text = raw.decode("cp949")
            except UnicodeDecodeError as error:
                text = raw.decode("cp949", errors="replace")
                source["encoding"] = "cp949_with_replacement"
                result["issues"].append({"severity": "warning", "file": relative,
                    "reason": "invalid CP949 byte sequence; raw file preserved in originals",
                    "byte_offset": error.start})
            match = NUMERIC_MAP_NAME.fullmatch(path.name)
            file_id = int(match.group(1)) if match else None
            for number, line in enumerate(text.splitlines(), 1):
                before_comment, separator, comment = line.partition(";")
                if separator:
                    source["comments"].append({"line": number, "text": comment.strip()})
                    if table == "global_events":
                        type_comment = re.fullmatch(r"\s*(\d+)\s*:\s*(.*)", comment)
                        if type_comment:
                            result["event_types"].append({"id": int(type_comment.group(1)),
                                "label_ko": type_comment.group(2).strip(),
                                "source": {"file": relative, "line": number}})
                row = before_comment.strip()
                if not row:
                    continue
                provenance = {"file": relative, "line": number}
                if table == "spawns" and row == "DefaultMopRegenOff":
                    result["directives"].append({"map_id": file_id, "name": row,
                                                   "source": provenance})
                    continue
                tokens = row.split()
                try:
                    record = parser(tokens)
                    if file_id is not None:
                        record["shop_id" if table == "shops" else "map_id"] = file_id
                    record["source"] = provenance
                    record["raw_fields"] = tokens
                    result[table].append(record)
                except ValueError as error:
                    result["issues"].append({"severity": "error", "table": table,
                        **provenance, "reason": str(error), "raw_line": line})
            result["sources"].append(source)
    result["excluded_variants"] = [p.relative_to(data_root).as_posix()
        for p in sorted(data_root.rglob("*.rsm"))
        if p.relative_to(data_root).as_posix() not in selected]
    ids = Counter(row["id"] for row in result["monsters"])
    for monster_id, count in ids.items():
        if count > 1:
            result["issues"].append({"severity": "warning", "table": "monsters",
                "reason": "duplicate monster ID retained", "monster_id": monster_id, "count": count})
    for row in result["spawns"]:
        if row["monster_id"] not in ids:
            result["issues"].append({"severity": "warning", "table": "spawns", **row["source"],
                "reason": "monster ID absent from imported canonical stats", "monster_id": row["monster_id"]})
    result["summary"] = {key: len(result[key]) for key in
        ("monsters", "spawns", "events", "global_events", "event_types", "shops", "map_shops", "npcs", "special_drops",
         "directives", "sources", "excluded_variants")}
    result["summary"]["issues_by_severity"] = dict(Counter(i["severity"] for i in result["issues"]))
    result["summary"]["spawn_maps"] = len({s["map_id"] for s in result["spawns"]})
    return result


def main() -> None:
    project = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path,
        default=project / "originals/2-RedMoon38Fixed-RaGEZONE-/Bin/Data")
    parser.add_argument("--out", type=Path, default=project / "data/content.json")
    args = parser.parse_args()
    result = import_content(args.root)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result["summary"], indent=2))
    print(f"Wrote {args.out}")


if __name__ == "__main__":
    main()
