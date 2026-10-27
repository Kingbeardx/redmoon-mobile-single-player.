#!/usr/bin/env python3
"""Bundle the portable project, recovered data and evidence, without originals."""
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'build/redmoon-mobile-source.zip'
INCLUDE_DIRS = ('tools', 'tests', 'docs', 'data', 'game', 'references')
EVIDENCE = ('archive-manifest.json', 'pe-report.json', 'coff-symbols.json',
            'svMapServer-selected.asm', 'content-comparison.json', 'nested-map-manifest.json',
            'v09-hud.png', 'v09-shop.png', 'v09-bio.png', 'v08-audio.png',
            'v09-smoke.log', 'v09-adventure.log', 'v09-input_smoke.log',
            'v09-upstream_features.log', 'v09-recovery_and_market.log',
            'v09-recovered_items.log', 'v09-new_adventure.log', 'v09-doctor_dialogue.log',
            'v09-creation_ui.log', 'v09-end_to_end.log', 'v09-accessibility.log',
            'v09-inventory_dialogue.log', 'v09-music_playback.log', 'v09-v09_features.log',
            'v09-python.log', 'v09-rules.log', 'v09-build.json',
            'new-character.asm', 'default-position.asm')


def main():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    files = [ROOT / 'README.md', ROOT / 'requirements-analysis.txt', ROOT / '.gitignore']
    for directory in INCLUDE_DIRS:
        files.extend(p for p in (ROOT / directory).rglob('*') if p.is_file()
                     and not {'.godot', '__pycache__', 'build', 'art'}.intersection(p.relative_to(ROOT).parts)
                     and p.suffix not in ('.pyc', '.keystore', '.jks'))
    files.extend(ROOT / 'analysis' / name for name in EVIDENCE)
    with zipfile.ZipFile(OUTPUT, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(set(files)):
            if not path.is_file():
                raise FileNotFoundError(path)
            archive.write(path, Path('redmoon-mobile') / path.relative_to(ROOT))
    with zipfile.ZipFile(OUTPUT) as archive:
        failure = archive.testzip()
        if failure:
            raise ValueError(f'ZIP validation failed: {failure}')
    print(f'{OUTPUT}: {OUTPUT.stat().st_size:,} bytes, {len(files)} entries')


if __name__ == '__main__':
    main()
