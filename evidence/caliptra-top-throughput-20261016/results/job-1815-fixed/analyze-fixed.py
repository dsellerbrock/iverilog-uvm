#!/usr/bin/env python3
import csv
import gzip
import json
import math
from pathlib import Path
import re
import statistics
import sys

root = Path(sys.argv[1])
window_re = re.compile(
    r"MCYCLE_WINDOW start=(\d+) end=(\d+) cycles=(\d+) elapsed_ns=(\d+)"
)
events = list(csv.DictReader(
    (root / "results/events.tsv").open(), delimiter="\t"
))
runs = {}
for event in events:
    key = (event["case"], event["variant"], int(event["repeat"]))
    evidence = root / "runs" / f'{event["case"]}-r{event["repeat"]}-{event["variant"]}'
    match = window_re.fullmatch((evidence / "window.txt").read_text().strip())
    assert match, key
    start, end, cycles, elapsed_ns = map(int, match.groups())
    assert end - start == cycles and cycles >= 2000 and elapsed_ns > 0, key
    rates = cycles * 1_000_000_000 / elapsed_ns
    hex_inputs = {}
    for line in (evidence / "generated-hex.tsv").read_text().splitlines():
        digest, name = line.split("\t", 1)
        hex_inputs[name] = digest
    assert hex_inputs, f"no generated firmware hex inputs for {key}"
    runs[key] = {
        "start": start,
        "end": end,
        "cycles": cycles,
        "elapsed_ns": elapsed_ns,
        "cycles_per_second": rates,
        "runner_exit": int(event["runner_exit"]),
        "hex_inputs": hex_inputs,
        "log": evidence / "sim.log.gz",
    }

cases = (
    "smoke_test_dma_aes_gcm_short_1_dword",
    "smoke_test_sha256",
    "cptra_ss_test_rom",
)
variants = ("base", "main")
assert len(events) == 18 and len(runs) == 18
assert all(row["runner_exit"] == 1 for row in runs.values()), "expected early-stop wrapper status for fixed-window samples"

def normalized_log(path):
    with gzip.open(path, "rt", errors="replace") as source:
        return "\n".join(
            line for line in source.read().splitlines()
            if not line.startswith(("MCYCLE_WINDOW ", "CALIPTRA_PROGRESS_HEARTBEAT "))
        )

log_diffs = []
for case in cases:
    expected_inputs = None
    for repeat in (1, 2, 3):
        for variant in variants:
            row = runs[(case, variant, repeat)]
            if expected_inputs is None:
                expected_inputs = row["hex_inputs"]
            assert row["hex_inputs"] == expected_inputs, (case, repeat, variant, "firmware input mismatch")
        base_log = normalized_log(runs[(case, "base", repeat)]["log"])
        main_log = normalized_log(runs[(case, "main", repeat)]["log"])
        if base_log != main_log:
            log_diffs.append((case, repeat))
assert not log_diffs, f"simulation output differs after removing the timing marker: {log_diffs}"

summary = {"tests": {}, "comparison": {}, "output_logs_identical": True}
lines = [
    "# End-to-end Caliptra top-level throughput",
    "",
    "Each sample covers the same 2,000 mcycle interval (100–2,100) in the "
    "full Caliptra top-level testbench. Runs were interleaved, one process at "
    "a time, pinned to one Slurm CPU. Spread is (max - min) / median.",
    "",
    "| Test | Build | Median cycles/s | Min–max | Spread |",
    "|---|---|---:|---:|---:|",
]

ratios = []
base_total_cycles = main_total_cycles = 0
base_total_ns = main_total_ns = 0
for case in cases:
    summary["tests"][case] = {}
    medians = {}
    for variant in variants:
        samples = [runs[(case, variant, repeat)] for repeat in (1, 2, 3)]
        rates = [row["cycles_per_second"] for row in samples]
        median = statistics.median(rates)
        spread = (max(rates) - min(rates)) / median * 100
        medians[variant] = median
        summary["tests"][case][variant] = {
            "median_cycles_per_second": median,
            "min_cycles_per_second": min(rates),
            "max_cycles_per_second": max(rates),
            "spread_percent": spread,
            "samples": [{
                "cycles": row["cycles"],
                "elapsed_ns": row["elapsed_ns"],
                "cycles_per_second": row["cycles_per_second"],
                "runner_exit": row["runner_exit"],
            } for row in samples],
        }
        lines.append(
            f"| {case} | {variant} | {median:.3f} | "
            f"{min(rates):.3f}–{max(rates):.3f} | {spread:.2f}% |"
        )
    ratio = medians["main"] / medians["base"]
    ratios.append(ratio)
    lines.append(f"| | main vs base | | | {(ratio - 1) * 100:+.2f}% |")
    for variant in variants:
        rows = [runs[(case, variant, repeat)] for repeat in (1, 2, 3)]
        median_cycles = statistics.median([row["cycles"] for row in rows])
        median_ns = statistics.median([row["elapsed_ns"] for row in rows])
        if variant == "base":
            base_total_cycles += median_cycles
            base_total_ns += median_ns
        else:
            main_total_cycles += median_cycles
            main_total_ns += median_ns

gmean = math.exp(sum(math.log(value) for value in ratios) / len(ratios))
base_pooled = base_total_cycles * 1_000_000_000 / base_total_ns
main_pooled = main_total_cycles * 1_000_000_000 / main_total_ns
summary["comparison"] = {
    "geometric_mean_speedup_percent": (gmean - 1) * 100,
    "pooled_base_cycles_per_second": base_pooled,
    "pooled_main_cycles_per_second": main_pooled,
    "pooled_speedup_percent": (main_pooled / base_pooled - 1) * 100,
}
lines.extend([
    "",
    f"Geometric-mean cumulative speedup across the three tests: {(gmean - 1) * 100:+.2f}%.",
    f"Equal-window pooled throughput: {base_pooled:.3f} → {main_pooled:.3f} cycles/s "
    f"({(main_pooled / base_pooled - 1) * 100:+.2f}%).",
    "",
    "The timing marker intentionally stops the simulation before testcase completion; "
    "these are fixed-window throughput measurements, not firmware pass results.",
    "The generated firmware .hex inputs and simulator output logs matched across builds.",
    "",
])
(root / "results/summary.json").write_text(json.dumps(summary, indent=2) + "\n")
(root / "results/summary.md").write_text("\n".join(lines))
