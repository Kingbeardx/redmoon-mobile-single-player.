# Recovered item and skill table structure

`tools/binary_content.py` decodes every byte of the six supplied RSI tables and
the RMI skill table into `data/binary-content.json`. Names and descriptions are
CP949 Korean text. This is recovered content, not reconstructed combat code.

The original and `38Fixed` archives contain byte-identical copies of all seven
tables. The importer selects the `38Fixed` copy and stores a SHA-256, source path,
record offset, record size, and serialized fields for provenance and exact
reconstruction. It does not run any original binary.

| Source | Declared value | Decoded slots | Named slots |
| --- | ---: | ---: | ---: |
| `ItemInfo01.rsi` | 241 | 242 | 160 |
| `ItemInfo02.rsi` | 129 | 130 | 129 |
| `ItemInfo03.rsi` | 304 | 305 | 109 |
| `ItemInfo04.rsi` | 45 | 46 | 35 |
| `ItemInfo05.rsi` | 194 | 195 | 177 |
| `ItemInfo06.rsi` | 255 | 256 | 176 |
| `skill00.rmi` | 382 | 382 | 150 |

There are **1,174 item slots, including 786 named slots**, and **382 skill slots,
including 150 named slots**. Empty slots are retained because positional indices
can be referenced by other tables. A named slot is not proof that the original
game makes the item available or the skill usable.

## Strings

The files use MFC-style ANSI length-prefixed strings. Lengths below 255 are one
byte, followed by that many CP949 bytes. The parser also supports the ANSI
`FF + uint16` and `FF FFFF + uint32` extended forms; those forms are independently
tested. It rejects the MFC Unicode marker because Unicode handling is outside
the observed format. Every source string decodes strictly with no replacement
characters. The exact length prefix and payload are retained, so re-encoding is
byte-identical rather than relying on a potentially ambiguous CP949 conversion.

## RSI framing

The file begins with the string `RedMoon ItemInfo File 1.0`, a little-endian
32-bit category value, then a little-endian 32-bit **maximum slot index**. The
following array contains maximum index + 1 records, including slot zero.

Each record has:

1. Eight bytes, also exposed as two unsigned little-endian 32-bit values.
2. A name string.
3. A description string.
4. Seventy-four opaque bytes.

This exact layout consumes all six files without gaps or trailing bytes. The
first prefix value usually matches the file category for populated records;
empty records commonly use zero. The second prefix value appears to be a visual
or subcategory reference, but that meaning has not been verified. The numeric
tail appears to contain stats, requirements, flags, and price-like values; the
importer deliberately does not label those fields without binary-code evidence.

For example, slot 1 of `ItemInfo01.rsi` recovers the name `우드소드` (wood sword)
and a description of a wooden stick carved into a sword. Slot 1 of
`ItemInfo04.rsi` is `붕어빵`, a food item. Category 5 slot 0 is named `돈` (money),
so slot zero must not be discarded universally.

## RMI framing

The file begins with `RedMoon Skill Info File V 1.0`, followed by a little-endian
32-bit **record count** of 382. A framing of one opaque byte, description string,
name string, and 38 opaque bytes consumes the complete file. The leading byte
has observed values 0, 1, and 2. Its semantic meaning and the grouping of numeric
fields across record boundaries are inferred rather than confirmed by the
server serializer. The JSON keeps these bytes opaque and makes no combat-rule
claims from them.

Recovered names include `회복`, `치료`, and `소울스피어`, with descriptive text.
These descriptions help identify skills but do not establish damage formulas,
target rules, cooldown units, or exact effect behavior.

## Validation and limits

Run from the project directory:

```sh
python3 tools/binary_content.py
python3 -m unittest discover -s tests -p 'test_binary_content.py' -v
```

Six tests cover all seven real files with byte-for-byte reconstruction, inclusive
item indexing, truncated/trailing input rejection, the ANSI length forms,
invalid encoding/unsupported Unicode rejection, and oversized length bounds.
All passed on the supplied archives. `encode_table` rebuilds from retained
serialized fields; changing the human-readable name alone does not edit the
binary file.

`Map00029.rmm` separately begins with `RedMoon MapData 1.0`, the little-endian
values 200 and 200, then the CP949 name `주택가3` and the value 29. This confirms
a map-oriented binary header; the remaining map format is outside this decoder.

These tables contain no sprite images, textures, sounds, or animation frames.
They can support a mobile content database, but complete offline gameplay still
requires recovered or reimplemented game rules and a renderer with assets.
