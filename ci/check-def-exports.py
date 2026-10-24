#!/usr/bin/env python3
"""Fail if ivl.def and the extern functions in ivl_target.h disagree.

Windows links targets against ivl.def, so a function declared in
ivl_target.h but missing from ivl.def builds fine on Linux and macOS
and only fails at link time on MINGW64/UCRT64/CLANG64.
"""
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
header = (root / "ivl_target.h").read_text()
header = re.sub(r"/\*.*?\*/", "", header, flags=re.S)
header = re.sub(r"//.*", "", header)
declared = set(re.findall(r"\bextern\b[^;{}()]*?\b(ivl_\w+)\s*\(", header))

lines = (root / "ivl.def").read_text().split()
exported = set(lines) - {"EXPORTS"}

missing = sorted(declared - exported)
stale = sorted(exported - declared)
for name in missing:
    print(f"ivl.def: missing export {name} (declared in ivl_target.h)")
for name in stale:
    print(f"ivl.def: stale export {name} (not declared in ivl_target.h)")
if missing or stale:
    sys.exit(1)
print(f"ivl.def: {len(exported)} exports match ivl_target.h")
