#!/usr/bin/env python3
"""Extract the supplied RARs without executing their contents; record hashes.

Requires 7-Zip (7zz/7z), because libarchive fails CRC checks on these RAR files.
"""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path, PurePosixPath


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def validate_listing(listing):
    entries = listing.split('----------\n', 1)
    if len(entries) != 2:
        raise ValueError('Unrecognized 7-Zip listing')
    total = 0
    count = 0
    for record in entries[1].split('\n\n'):
        fields = dict(line.split(' = ', 1) for line in record.splitlines() if ' = ' in line)
        if 'Path' not in fields:
            continue
        name = fields['Path'].replace('\\', '/')
        p = PurePosixPath(name)
        if p.is_absolute() or '..' in p.parts or re.match(r'^[A-Za-z]:', name):
            raise ValueError(f'Unsafe archive path: {name!r}')
        if any('Link' in key and fields[key] for key in fields):
            raise ValueError('Archive links are unsupported')
        total += int(fields.get('Size', '0'))
        count += 1
        if total > 1_000_000_000 or count > 20_000:
            raise ValueError('Archive exceeds the inspection size limit')


def manifest(root):
    return [{'path': p.relative_to(root).as_posix(), 'bytes': p.stat().st_size,
             'sha256': digest(p)} for p in sorted(root.rglob('*')) if p.is_file()]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archives', nargs='+', type=Path)
    parser.add_argument('--output', type=Path, default=Path('originals'))
    parser.add_argument('--manifest', type=Path, default=Path('analysis/archive-manifest.json'))
    parser.add_argument('--sevenzip', default=shutil.which('7zz') or shutil.which('7z'))
    args = parser.parse_args()
    if not args.sevenzip:
        parser.error('Install 7-Zip or pass --sevenzip /path/to/7zz')
    args.output.mkdir(parents=True, exist_ok=True)
    records = []
    for archive in args.archives:
        archive = archive.resolve()
        listed = subprocess.run([args.sevenzip, 'l', '-slt', str(archive)],
                                check=True, capture_output=True, text=True)
        validate_listing(listed.stdout.replace('\r\n', '\n'))
        target = args.output / archive.stem
        with tempfile.TemporaryDirectory(dir=args.output, prefix='.extract-') as temp:
            stage = Path(temp) / 'contents'
            subprocess.run([args.sevenzip, 'x', '-y', str(archive), '-o' + str(stage)],
                           check=True, stdout=subprocess.DEVNULL)
            if any(p.is_symlink() for p in stage.rglob('*')):
                raise ValueError('Extracted symbolic link rejected')
            entries = manifest(stage)
            if target.exists():
                if manifest(target) != entries:
                    raise ValueError(f'{target} already exists with different contents; refusing overwrite')
            else:
                stage.rename(target)
        records.append({'archive': archive.name, 'sha256': digest(archive),
                        'extraction_exit': 0, 'entries': entries})
        print(f'{archive.name}: {len(entries)} files verified')
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(json.dumps(records, indent=2) + '\n')


if __name__ == '__main__':
    main()
