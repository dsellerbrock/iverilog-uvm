#!/usr/bin/env python3
"""Check that the Windows import library exports the covergroup target API."""
import argparse
from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--exports', type=Path, default=root / 'ivl.def')
args = parser.parse_args()
api = set(re.findall(r'\b(ivl_type_covgrp_\w+)\s*\(',
                     (root / 'ivl_target.h').read_text()))
exports = {line.split()[0] for line in args.exports.read_text().splitlines()
           if line.strip()}
missing = sorted(api - exports)
if not api or missing:
    raise SystemExit('FAIL: missing covergroup exports: ' +
                     (', '.join(missing) if api else 'no API declarations found'))
print(f'PASS: all {len(api)} covergroup API functions exported')
