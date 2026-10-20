#!/usr/bin/env python3
"""Summarize the fixed 2,000-cycle WP7 Caliptra windows."""

import csv
import json
import math
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
cases = ("smoke_test_dma_aes_gcm_short_1_dword", "smoke_test_sha256",
         "cptra_ss_test_rom")
rows = []
ratios = []
for case in cases:
    rates = {}
    for side in ("reference", "candidate", "stats"):
        path = root / "caliptra/logs" / f"{case}-{side}" / "sim.log"
        match = re.search(
            r"^MCYCLE_WINDOW start=100 end=2100 cycles=2000 elapsed_ns=(\d+)$",
            path.read_text(), re.MULTILINE)
        if not match:
            raise SystemExit(f"missing 2,000-cycle window: {path}")
        rates[side] = 2_000_000_000_000 / int(match.group(1))
    ratio = rates["candidate"] / rates["reference"]
    ratios.append(ratio)
    stats_log = (root / "caliptra/out" / f"{case}-stats" / case / "sim.log").read_text()
    stats_match = re.search(r"^VVP_PERF_STATS (\{.*\})$", stats_log, re.MULTILINE)
    if not stats_match:
        raise SystemExit(f"missing tier counters: {case}")
    tiers = json.loads(stats_match.group(1))["randomize_tiers"]
    rows.append((case, rates["reference"], rates["candidate"], rates["stats"],
                 ratio, tiers))

with (root / "results/caliptra-cycles.csv").open("w", newline="") as stream:
    writer = csv.writer(stream)
    writer.writerow(("test", "base_cycles_per_second", "candidate_cycles_per_second",
                     "stats_cycles_per_second", "candidate_over_base", "tier_counts"))
    for case, base, candidate, stats, ratio, tiers in rows:
        writer.writerow((case, f"{base:.6f}", f"{candidate:.6f}", f"{stats:.6f}",
                         f"{ratio:.6f}", json.dumps(tiers, sort_keys=True)))
print("test,base_cycles/s,candidate_cycles/s,candidate/base,tier_counts")
for case, base, candidate, _, ratio, tiers in rows:
    print(f"{case},{base:.6f},{candidate:.6f},{ratio:.6f},{json.dumps(tiers, sort_keys=True)}")
print(f"three-test geometric mean candidate/base={math.prod(ratios) ** (1 / len(ratios)):.6f}")
