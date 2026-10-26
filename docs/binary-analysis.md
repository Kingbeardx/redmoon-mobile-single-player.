# Native binary analysis

No original executable was run. `tools/inspect_pe.py` uses pefile and Capstone to
inventory headers/imports/exports, parse COFF symbols, and disassemble a selected
set of named functions. Results are in `analysis/pe-report.json`,
`analysis/coff-symbols.json`, and `analysis/svMapServer-selected.asm`.

There are 30 EXE/DLL paths across the first two archives, representing 15 distinct
files. Thirteen distinct files are native PE32 x86 images (machine 0x14c). The two
small files named Web/info.dll and rmp.dll are not PE images. Both distributions'
native binaries have identical SHA-256 hashes. No C/C++ game source, PC client
executable, Android binary, or iOS binary was found.

The game service is split between svIP.exe, svMapCenter.exe, svMapServer.exe,
svAliveIP.exe, and RMServerMgr.exe. Imports establish Windows/MFC, Winsock, and
ODBC dependencies; rmDB.dll supplies database integration. SQL MDF/LDF files are
also present. These executables cannot be relinked into ARM Android/iOS apps.
The offline reconstruction replaces the service and database boundary with local
state while translating behavior from evidence.

## Symbols and addresses

svMapServer.exe retains 6,412 COFF entries including auxiliary records, yielding
5,295 named records and 1,470 function symbols. Names cover map serialization,
collision, combat, stat initialization, level-up, event loading, and monster AI.
This is useful structure, not recovered original source code.

In these linked PE images the COFF Value is an RVA, not an object-file section
offset. Add image base 0x00400000 to obtain a virtual address. The inspector
cross-checks matching named DLL exports against symbol RVAs; the selected game
server addresses also resolve to plausible disassembled functions.

| Function | Virtual address | Finding |
|---|---|---|
| CrsMap::Serialize | 0x00486920 | SMM field and grid order |
| CrsMap::GetCanExistUser | 0x00486300 | Bounds and two mode-dependent permission bits |
| CrsMap::CheckEnter | 0x00486680 | Permission plus occupancy nibble checks |
| CMapServerClient::InitializeHPMax | 0x004346c0 | HP maximum arithmetic |
| CMapServerClient::InitializeMPMax | 0x00434780 | Piecewise MP maximum arithmetic |
| CMapServerClient::DoLevelUp | 0x00437fb0 | Base level-up bonus increment |

## Recovered rule subset

`tools/recovered_rules.py` implements three isolated calculations with unsigned
32-bit wrapping, not the entire methods or their side effects:

- HP maximum: `50 + floor(P / 15) * floor(P / 10)`, where P is effective Power
  after the original status/equipment adjustment. The original method halves the
  base value when a particular status bit is set, then adds equipment contribution.
- MP maximum: the same quadratic form for effective Spirit S <= 20,000;
  `273 * S - 0x2a9df6` above that threshold.
- Newly reached levels divisible by 100 receive a base bonus of 3 points;
  other levels receive 2. Other level-up rewards and effects are not covered.

The division formulas are checked against the actual x86 reciprocal multiply and
shift operations over every input from 0 through 20,000 plus 10,000 deterministic
uint32 samples. MP tests cover the threshold and high-input wrapping. These are
static arithmetic comparisons, not comparisons with a running legacy server.

The playable prototype currently keeps these formulas separate from its simple
combat model. It does not represent prototype HP/damage/XP as original mechanics.
The next step is to recover the complete effective-stat pipeline and surrounding
rules before integrating this subset into a faithful character simulation.
