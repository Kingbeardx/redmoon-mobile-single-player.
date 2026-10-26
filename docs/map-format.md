# SMM map format

`tools/map_import.py` decodes all 196 supplied SMM maps exactly, covering 1,916,400
cells. The structures are cross-checked against CrsMap::Serialize at VA 0x486920
in the supplied svMapServer.exe. The nested Map.rar contains 254 members, all
byte-identical to the expanded Map directory; see the nested-map manifest.

| Field | Representation |
|---|---|
| Signature | one-byte length + `RedMoon Server MapData 1.0` |
| Width, height | two little-endian uint32 values |
| Name | one-byte byte-length + CP949 text |
| Map ID | little-endian uint32 |
| Cells | width × height records, eight bytes each, y outer/x inner |

The serializer writes the high 32-bit word of the in-memory 64-bit cell before
the low word; both words themselves are little endian. The importer preserves
all raw cell bytes in base64. It rejects invalid signatures, truncated streams,
trailing bytes, invalid CP949 names, excessive dimensions, duplicate IDs, and
unsupported extended string prefixes. Every supplied file uses short strings.

## Static passability evidence

CrsMap::GetCanExistUser at 0x486300 rejects x <= 0, y <= 0, x >= width, or
y >= height. It then extracts bit 48 for mode 0 or bit 56 for mode 1 from the
in-memory 64-bit cell. These correspond to bit 0 of serialized cell byte 2 or 3.
CrsMap::CheckEnter at 0x486680 additionally requires a zero nibble at bits 40–43
or 44–47 respectively, corresponding to serialized byte 1. Those nibbles are
zero in the supplied static files, but the decoder retains both checks.

The JSON exposes separate `walkable_modes` masks and their intersection as
`walkable`. The intersection is a conservative prototype choice; the meaning
and switching behavior of the original two modes are not reconstructed. Dynamic
occupancy by entities is also not part of the static mask.

`start` is chosen at the center of the largest four-connected walkable component.
It is a prototype convenience, not a recovered player spawn. All 196 maps have
at least one traversable cell. The empty `transitions` array means transitions
are not decoded; it does not prove that the source has no transitions.

These are server occupancy grids, not textured scenes. The prototype's 48×24
pixel isometric projection, colors, and actors are new placeholder rendering.
The one Map00029.rmm has a different client-oriented signature and remains an
unimplemented resource-format lead; it supplies no artwork by itself.
