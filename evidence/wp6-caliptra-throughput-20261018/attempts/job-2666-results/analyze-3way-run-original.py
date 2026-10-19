#!/usr/bin/env python3
import csv
import gzip
import json
import math
import re
import statistics
import sys
from pathlib import Path

root = Path(sys.argv[1])
cases = ("smoke_test_dma_aes_gcm_short_1_dword", "smoke_test_sha256", "cptra_ss_test_rom")
variants = ("base", "main", "candidate")
events = list(csv.DictReader((root / "results/events.tsv").open(), delimiter="\t"))
assert len(events) == 27, len(events)
window_re = re.compile(r"MCYCLE_WINDOW start=(\d+) end=(\d+) cycles=(\d+) elapsed_ns=(\d+)")
runs = {}

def normalized(path):
    with gzip.open(path, "rt", errors="replace") as source:
        return "\n".join(
            line for line in source.read().splitlines()
            if not line.startswith(("MCYCLE_WINDOW ", "CALIPTRA_PROGRESS_HEARTBEAT "))
        )

for event in events:
    case, variant, repeat = event["test"], event["variant"], int(event["repeat"])
    key = (case, variant, repeat)
    assert case in cases and variant in variants and repeat in (1, 2, 3), key
    evidence = root / "runs" / f"{case}-r{repeat}-{variant}"
    match = window_re.fullmatch((evidence / "window.txt").read_text().strip())
    assert match, key
    start, end, cycles, elapsed_ns = map(int, match.groups())
    assert (start, end, cycles) == (100, 2100, 2000), (key, match.groups())
    assert elapsed_ns > 0
    hex_inputs = {}
    for line in (evidence / "generated-hex.tsv").read_text().splitlines():
        digest, name = line.split("\t", 1)
        hex_inputs[name] = digest
    assert len(hex_inputs) == 39, (key, len(hex_inputs))
    runner_exit = int(event["runner_exit"])
    assert runner_exit == 1, (key, runner_exit)
    runs[key] = {
        "cycles": cycles,
        "elapsed_ns": elapsed_ns,
        "rate": cycles * 1_000_000_000 / elapsed_ns,
        "runner_exit": runner_exit,
        "hex": hex_inputs,
        "log": evidence / "sim.log.gz",
    }
assert len(runs) == 27

for case in cases:
    expected_hex = None
    expected_log = None
    for repeat in (1, 2, 3):
        for variant in variants:
            row = runs[(case, variant, repeat)]
            if expected_hex is None:
                expected_hex = row["hex"]
            assert row["hex"] == expected_hex, (case, repeat, variant, "firmware inputs differ")
            log = normalized(row["log"])
            if expected_log is None:
                expected_log = log
            assert log == expected_log, (case, repeat, variant, "normalized simulation logs differ")

summary = {
    "campaign_base": "f9f8e0a79f230f38da6cbb4445994ad1075ad531",
    "main_before_601": "631b7a869faaa05216d8749224520227b4b23d43",
    "pr_601_candidate": "3b620c5ea5857ba7c022a7fba058f8a31b7ac564",
    "window": {"start": 100, "end": 2100, "cycles": 2000},
    "tests": {},
    "comparison": {},
    "all_inputs_identical": True,
    "all_normalized_logs_identical": True,
}
geo = {"main_vs_base": [], "candidate_vs_base": [], "candidate_vs_main": []}
pooled = {variant: {"cycles": 0, "ns": 0} for variant in variants}
lines = [
    "# End-to-end Caliptra throughput: campaign base, main, and #601",
    "",
    "Each sample covers 2,000 mcycles (100–2,100) in the full Caliptra top-level testbench. "
    "Three repeats per test and build were interleaved on one Slurm CPU. Spread is "
    "(maximum minus minimum) divided by median.",
    "",
    "| Test | Campaign base f9f8e0a | Main 631b7a8 before #601 | #601 candidate | Candidate vs base | Candidate vs main |",
    "|---|---:|---:|---:|---:|---:|",
]
for case in cases:
    data = {}
    for variant in variants:
        rows = [runs[(case, variant, repeat)] for repeat in (1, 2, 3)]
        rates = [row["rate"] for row in rows]
        median = statistics.median(rates)
        spread = (max(rates) - min(rates)) / median * 100
        data[variant] = {
            "median_cycles_per_second": median,
            "min_cycles_per_second": min(rates),
            "max_cycles_per_second": max(rates),
            "spread_percent": spread,
            "samples": [{
                "cycles": row["cycles"],
                "elapsed_ns": row["elapsed_ns"],
                "cycles_per_second": row["rate"],
                "runner_exit": row["runner_exit"],
            } for row in rows],
        }
        pooled[variant]["cycles"] += statistics.median([row["cycles"] for row in rows])
        pooled[variant]["ns"] += statistics.median([row["elapsed_ns"] for row in rows])
    summary["tests"][case] = data
    ratios = {
        "main_vs_base": data["main"]["median_cycles_per_second"] / data["base"]["median_cycles_per_second"],
        "candidate_vs_base": data["candidate"]["median_cycles_per_second"] / data["base"]["median_cycles_per_second"],
        "candidate_vs_main": data["candidate"]["median_cycles_per_second"] / data["main"]["median_cycles_per_second"],
    }
    for key, ratio in ratios.items():
        geo[key].append(ratio)
    cells = [
        f'{data[name]["median_cycles_per_second"]:.3f} ({data[name]["spread_percent"]:.2f}%)'
        for name in variants
    ]
    lines.append(
        f"| {case} | {cells[0]} | {cells[1]} | {cells[2]} | "
        f"{(ratios['candidate_vs_base'] - 1) * 100:+.2f}% | "
        f"{(ratios['candidate_vs_main'] - 1) * 100:+.2f}% |"
    )

for key, values in geo.items():
    speedup = math.exp(sum(math.log(value) for value in values) / len(values))
    summary["comparison"][key + "_geometric_mean_percent"] = (speedup - 1) * 100
    lines.append(f"\nThree-test geometric-mean {key.replace('_', ' ')}: {(speedup - 1) * 100:+.2f}%.")
for variant in variants:
    summary["comparison"][variant + "_pooled_cycles_per_second"] = (
        pooled[variant]["cycles"] * 1_000_000_000 / pooled[variant]["ns"]
    )
lines.extend([
    "",
    "All 39 generated firmware hex inputs matched across every repeat and build. "
    "Normalized simulator logs matched after removing only the mcycle-window marker and "
    "progress-heartbeat lines. VPI deliberately stops each incomplete test at mcycle 2,100; "
    "the expected runner exit is 1, so these are bounded throughput samples, not firmware pass results.",
    "",
])
(root / "results/summary.json").write_text(json.dumps(summary, indent=2) + "\n")
(root / "results/summary.md").write_text("\n".join(lines))
