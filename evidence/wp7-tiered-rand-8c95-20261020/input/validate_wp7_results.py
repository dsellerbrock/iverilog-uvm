#!/usr/bin/env python3
"""Check the completed WP7 data set after its final packaging retry."""

import csv
import hashlib
import json
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
results = root / "results"
corpus = json.loads((results / "corpus-reconciled.json").read_text())
if len(corpus["benchmarks"]) != 18 or any(
        item.get("status") != "ok" or item.get("identical_all_runs") is not True
        for item in corpus["benchmarks"].values()):
    raise SystemExit("the reconciled corpus does not have 18 identical workloads")
with (results / "callgrind.csv").open(newline="") as stream:
    rows = list(csv.DictReader(stream))
if len(rows) != 18 or any(row["outputs_identical"] != "yes" for row in rows):
    raise SystemExit("Callgrind table is incomplete or has an output mismatch")
with (results / "tier-focus.csv").open(newline="") as stream:
    focus = {row["tier"]: row for row in csv.DictReader(stream)}
if set(focus) != {"T0", "T4"} or any(row["outputs_identical"] != "yes"
                                       for row in focus.values()):
    raise SystemExit("focused T0/T4 result is incomplete")
hist = json.loads((results / "tier-hist-caliptra.json").read_text())
cases = ("smoke_test_dma_aes_gcm_short_1_dword", "smoke_test_sha256",
         "cptra_ss_test_rom")
if set(hist) != set(cases):
    raise SystemExit("Caliptra tier histogram is incomplete")
for case in cases:
    if any(hist[case]["tiers"].values()) or hist[case]["z3"]["contexts"]:
        raise SystemExit(f"unexpected randomization activity in {case}")
    for side in ("reference", "candidate", "stats"):
        evidence = root / "caliptra/logs" / f"{case}-{side}"
        if not (evidence / "sim.log").is_file() or not (evidence / "result.json").is_file():
            raise SystemExit(f"missing Caliptra output: {case}-{side}")
    def normalized(path):
        return "\n".join(line for line in path.read_text(errors="replace").splitlines()
                         if not line.startswith(("MCYCLE_WINDOW ",
                                                 "CALIPTRA_PROGRESS_HEARTBEAT ",
                                                 "VVP_PERF_STATS ")))
    logs = [root / "caliptra/logs" / f"{case}-{side}" / "sim.log"
            for side in ("reference", "candidate", "stats")]
    if normalized(logs[0]) != normalized(logs[1]) or normalized(logs[1]) != normalized(logs[2]):
        raise SystemExit(f"Caliptra normalized logs differ: {case}")
    def hex_files(path):
        return {item.relative_to(path).as_posix(): hashlib.sha256(item.read_bytes()).hexdigest()
                for item in sorted(path.rglob("*.hex"))}
    outputs = [root / "caliptra/out" / f"{case}-{side}" / case
               for side in ("reference", "candidate", "stats")]
    if hex_files(outputs[0]) != hex_files(outputs[1]) or hex_files(outputs[1]) != hex_files(outputs[2]):
        raise SystemExit(f"Caliptra generated firmware images differ: {case}")
with (results / "caliptra-cycles.csv").open(newline="") as stream:
    if len(list(csv.DictReader(stream))) != 3:
        raise SystemExit("Caliptra throughput table is incomplete")
(results / "validation.txt").write_text(
    "18 corpus outputs identical after one isolated waveform_fst retry; "
    "focused T0/T4 outputs identical; three Caliptra tests have identical "
    "normalized logs and complete tier/throughput records. The batch exited "
    "1 only during final checksum generation because a directory was passed "
    "to sha256sum; all measurements and comparison steps had completed.\n")
(results / "VALIDATED").write_text("yes\n")
print("validated corpus, focused tiers, and all three Caliptra runs")
