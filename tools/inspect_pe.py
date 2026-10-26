#!/usr/bin/env python3
"""Statically inventory original RedMoon PE images and recover embedded COFF names.

Requires pefile and capstone. Does not load or execute any original binary and
does not emit configuration files, database records, or unrestricted strings.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct

import capstone
import pefile


TARGET_PREFIXES = (
    "?GetAttack@", "?GetSkillAttack@", "?GetSkillDefence@",
    "?InitializeAttack@", "?InitializeAttackMinPercentage@",
    "?GetAttackSuccessful@", "?DoLevelUp@", "?ReadMopInfo@",
    "?ReadEvent@", "?Serialize@CrSkillInfo@", "?Serialize@CrItemInfoItem@",
    "?InitializeHPMax@", "?InitializeMPMax@", "?InitializeDPMax@",
    "?IsNormalAttackSpeed@", "?Serialize@CrsMap@", "?GetCanExistUser@",
    "?GetCanExistMop@", "?Move@CrsMap@", "?CheckEnter@CrsMap@",
    "?SetMapSize@CrsMap@", "?GetSpirit@CMopServer@",
)


def coff_symbols(pe: pefile.PE, raw: bytes) -> list[dict]:
    header = pe.FILE_HEADER
    start, count = header.PointerToSymbolTable, header.NumberOfSymbols
    if not start or not count:
        return []
    end = start + count * 18
    if end + 4 > len(raw):
        raise ValueError("COFF symbol table exceeds file")
    string_size = struct.unpack_from("<I", raw, end)[0]
    if string_size < 4 or end + string_size > len(raw):
        raise ValueError("COFF string table exceeds file")
    symbols, i = [], 0
    while i < count:
        name_raw, value, section, kind, storage, auxiliary = struct.unpack_from(
            "<8sIhHBB", raw, start + i * 18
        )
        if name_raw[:4] == b"\0" * 4:
            offset = struct.unpack_from("<I", name_raw, 4)[0]
            if not 4 <= offset < string_size:
                raise ValueError("COFF string offset out of range")
            name_end = raw.find(b"\0", end + offset, end + string_size)
            if name_end < 0:
                raise ValueError("Unterminated COFF name")
            name = raw[end + offset:name_end].decode("ascii", errors="replace")
        else:
            name = name_raw.rstrip(b"\0").decode("ascii", errors="replace")
        record = {"name": name, "section": section, "value": value,
                  "type": kind, "storage_class": storage, "auxiliary_count": auxiliary}
        if 0 < section <= len(pe.sections):
            # In these linked PE image COFF tables, Value is already an RVA,
            # unlike section-relative Value in relocatable COFF object files.
            # Cross-checked against named DLL exports and actual code prologues.
            rva = value
            record.update(rva=rva, va=pe.OPTIONAL_HEADER.ImageBase + rva)
        symbols.append(record)
        i += 1 + auxiliary
    if i != count:
        raise ValueError("COFF auxiliary count exceeds table")
    return symbols


def inspect(path: Path, root: Path) -> tuple[dict, list[dict], str]:
    raw = path.read_bytes()
    record = {"path": path.relative_to(root).as_posix(), "bytes": len(raw),
              "sha256": hashlib.sha256(raw).hexdigest()}
    try:
        pe = pefile.PE(data=raw)
    except pefile.PEFormatError:
        record.update(is_pe=False, note="Extension is EXE/DLL but contents are not a PE image")
        return record, [], ""
    symbols = coff_symbols(pe, raw)
    # Validate linked-image address interpretation with independently encoded
    # exports when the binary exposes named exports.
    symbol_addresses = {s["name"]: s["rva"] for s in symbols if "rva" in s}
    cross_checked = 0
    for exported in getattr(getattr(pe, "DIRECTORY_ENTRY_EXPORT", None), "symbols", []):
        if not exported.name:
            continue
        name = exported.name.decode("ascii", errors="replace")
        if name in symbol_addresses:
            if symbol_addresses[name] != exported.address:
                raise ValueError(f"COFF/export address mismatch: {path.name} {name}")
            cross_checked += 1
    record.update(
        is_pe=True, machine=hex(pe.FILE_HEADER.Machine),
        optional_magic=hex(pe.OPTIONAL_HEADER.Magic),
        image_base=hex(pe.OPTIONAL_HEADER.ImageBase),
        entry_rva=hex(pe.OPTIONAL_HEADER.AddressOfEntryPoint),
        coff_entry_count=pe.FILE_HEADER.NumberOfSymbols,
        coff_named_count=len(symbols),
        function_symbol_count=sum(s["type"] == 0x20 and s["section"] > 0 for s in symbols),
        coff_export_address_cross_checks=cross_checked,
        sections=[{"name": s.Name.rstrip(b"\0").decode("ascii", errors="replace"),
                   "rva": hex(s.VirtualAddress), "virtual_bytes": s.Misc_VirtualSize,
                   "raw_bytes": s.SizeOfRawData} for s in pe.sections],
        imports=[{"dll": d.dll.decode("ascii", errors="replace"),
                  "symbols": [s.name.decode("ascii", errors="replace") if s.name else
                              f"ordinal:{s.ordinal}" for s in d.imports]}
                 for d in getattr(pe, "DIRECTORY_ENTRY_IMPORT", [])],
        exports=[{"name": s.name.decode("ascii", errors="replace") if s.name else None,
                  "ordinal": s.ordinal, "rva": hex(s.address)}
                 for s in getattr(getattr(pe, "DIRECTORY_ENTRY_EXPORT", None), "symbols", [])],
    )
    disassembly = []
    if path.name.lower() == "svmapserver.exe":
        functions = sorted((s for s in symbols if s["type"] == 0x20 and s.get("section") == 1),
                           key=lambda s: (s["rva"], s["name"]))
        md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
        for symbol in functions:
            if not symbol["name"].startswith(TARGET_PREFIXES):
                continue
            next_rva = next((s["rva"] for s in functions if s["rva"] > symbol["rva"]),
                            pe.sections[0].VirtualAddress + pe.sections[0].Misc_VirtualSize)
            code = pe.get_data(symbol["rva"], next_rva - symbol["rva"])
            disassembly.extend([f"; {symbol['name']}",
                                f"; VA 0x{symbol['va']:08x}; next-symbol extent {len(code)} bytes"])
            disassembly.extend(f"{ins.address:08x}  {ins.bytes.hex():20s} {ins.mnemonic:8s} {ins.op_str}"
                               for ins in md.disasm(code, symbol["va"]))
            disassembly.append("")
    pe.close()
    return record, symbols, "\n".join(disassembly)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--originals", type=Path, default=Path(__file__).resolve().parents[1] / "originals")
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / "analysis")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    reports, all_symbols, seen = [], {}, set()
    for path in sorted(args.originals.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in (".exe", ".dll"):
            continue
        report, symbols, assembly = inspect(path, args.originals)
        reports.append(report)
        digest = report["sha256"]
        if digest in seen:
            continue
        seen.add(digest)
        if symbols:
            all_symbols[report["path"]] = symbols
        if assembly:
            (args.output / "svMapServer-selected.asm").write_text(assembly + "\n", encoding="utf-8")
    (args.output / "pe-report.json").write_text(json.dumps(reports, indent=2) + "\n", encoding="utf-8")
    (args.output / "coff-symbols.json").write_text(json.dumps(all_symbols, indent=2) + "\n", encoding="utf-8")
    print(f"Inspected {len(reports)} EXE/DLL paths, {len(seen)} distinct files; no originals executed.")


if __name__ == "__main__":
    main()
