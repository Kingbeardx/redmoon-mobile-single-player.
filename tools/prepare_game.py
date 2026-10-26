#!/usr/bin/env python3
"""Rebuild decoded content and copy it into the portable Godot project."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path,
                        default=ROOT / 'originals/2-RedMoon38Fixed-RaGEZONE-/Bin/Data')
    args = parser.parse_args()
    source = args.source.resolve()
    subprocess.run([sys.executable, str(ROOT / 'tools/map_import.py'), str(source / 'Map'),
                    '--output', str(ROOT / 'data')], check=True, cwd=ROOT)
    subprocess.run([sys.executable, str(ROOT / 'tools/content_import.py'),
                    '--root', str(source)], check=True, cwd=ROOT)
    subprocess.run([sys.executable, str(ROOT / 'tools/binary_content.py'),
                    '--source', str(source)], check=True, cwd=ROOT)
    shutil.copytree(ROOT / 'data', ROOT / 'game/data', dirs_exist_ok=True)
    print('Godot data refreshed. No legacy program was executed.')


if __name__ == '__main__':
    main()
