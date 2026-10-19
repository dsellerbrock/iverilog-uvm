#!/usr/bin/env python3
"""Apply the WP11 instruction and byte-output screen to Callgrind results."""

import csv
import json
import re
import sys
from pathlib import Path


def instructions(path):
    match = re.search(r"^summary:\s+(\d+)$", path.read_text(), re.MULTILINE)
    if not match:
        raise ValueError(f"missing Callgrind summary in {path}")
    return int(match.group(1))


def main(root):
    root = Path(root)
    profiles = root / "profiles"
    sides = {}
    for path in profiles.glob("*.callgrind"):
        match = re.fullmatch(r"(.+)-\d{2}-(reference|candidate)", path.stem)
        if match:
            sides.setdefault(match.group(1), {})[match.group(2)] = instructions(path)

    if len(sides) != 18 or any(set(pair) != {"reference", "candidate"}
                               for pair in sides.values()):
        raise ValueError(f"expected 18 paired workloads, found {len(sides)}")

    for group in ("rtl", "other"):
        result = json.loads((root / "screen" / group / "corpus.json").read_text())
        for name, item in result["benchmarks"].items():
            if item.get("identical_all_runs") is not True:
                raise ValueError(f"byte outputs differ for {name}")

    rows = []
    passed = True
    for name, pair in sorted(sides.items()):
        ref = pair["reference"]
        cand = pair["candidate"]
        change = (cand / ref - 1.0) * 100.0
        rows.append((name, ref, cand, change))
        if name == "rtl_pipe":
            passed &= change <= -10.0
        else:
            passed &= change <= 2.0

    writer = csv.writer(sys.stdout)
    writer.writerow(("workload", "reference_instructions", "candidate_instructions",
                     "candidate_change_pct"))
    writer.writerows((name, ref, cand, f"{change:.6f}") for name, ref, cand, change in rows)
    print(f"screen={'PASS' if passed else 'FAIL'}")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
