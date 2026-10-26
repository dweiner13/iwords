#!/usr/bin/env python3
"""Run upstream golden cases with our signed engine in an isolated data directory."""
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = root / '.build/words-source'
if not source.exists():
    raise SystemExit('Run scripts/build-engine.py first to fetch the pinned test fixtures.')
with tempfile.TemporaryDirectory(prefix='iwords-regression-') as temporary:
    work = Path(temporary)
    for file in (root / 'macOS/Dictionary/WORDS').iterdir():
        if file.is_file():
            shutil.copy2(file, work / file.name)
    shutil.copy2(source / 'test/WORD.MDV_template', work / 'WORD.MDV')
    for case in sorted((source / 'test').glob('[0-9][0-9]_*')):
        result = subprocess.run([str(work / 'words')], input=(case / 'input.txt').read_text(),
                                cwd=work, capture_output=True, text=True, timeout=60, check=True)
        actual = [line.rstrip() for line in result.stdout.splitlines()[18:-1]]
        expected = [line.rstrip() for line in (case / 'expected.txt').read_text().splitlines()]
        if actual != expected:
            raise SystemExit('FAIL ' + case.name)
        print('PASS ' + case.name)
