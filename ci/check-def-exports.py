#!/usr/bin/env python3
"""Fail if a Windows export list is missing a function.

Windows links targets against ivl.def, so a function declared in
ivl_target.h but missing from ivl.def builds fine on Linux and macOS
and only fails at link time on MINGW64/UCRT64/CLANG64.

The same holds for VPI modules: a vpi_/vpip_ function that vpi/ calls and
vvp/ defines (extern "C") must be exported in vvp/vvp.def or forwarded by
vpi/libvpi.c (#1443: vpip_print_finish_stats).
"""
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent


def code(path):
    text = re.sub(r"/\*.*?\*/", "", path.read_text(errors="ignore"), flags=re.S)
    return re.sub(r"//.*", "", text)


header = code(root / "ivl_target.h")
declared = set(re.findall(r"\bextern\b[^;{}()]*?\b(ivl_\w+)\s*\(", header))

lines = (root / "ivl.def").read_text().split()
exported = set(lines) - {"EXPORTS"}

missing = sorted(declared - exported)
stale = sorted(exported - declared)
for name in missing:
    print(f"ivl.def: missing export {name} (declared in ivl_target.h)")
for name in stale:
    print(f"ivl.def: stale export {name} (not declared in ivl_target.h)")

called = set()
for f in (root / "vpi").rglob("*.[ch]*"):
    called |= set(re.findall(r"\b(vpip?_\w+)\s*\(", code(f)))
defined = set()
for f in (root / "vvp").glob("*.cc"):
    defined |= set(re.findall(r'extern\s+"C"\s+[^;{()]*?\b(vpip?_\w+)\s*\([^;{]*\)\s*\{', code(f)))
vvp_exported = set((root / "vvp" / "vvp.def").read_text().split()) - {"EXPORTS"}
forwarded = set(re.findall(r"\b(vpip?_\w+)\s*\([^;{]*\)\s*\{", code(root / "vpi" / "libvpi.c")))
vvp_missing = sorted((called & defined) - vvp_exported - forwarded)
for name in vvp_missing:
    print(f"vvp.def: {name} is called from vpi/ and defined in vvp/, but neither exported in vvp.def nor forwarded by vpi/libvpi.c")

if missing or stale or vvp_missing:
    sys.exit(1)
print(f"ivl.def: {len(exported)} exports match ivl_target.h; "
      f"vvp: {len(called & defined)} vpi-called runtime functions all exported or forwarded")
