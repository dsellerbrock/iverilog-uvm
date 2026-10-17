#!/usr/bin/env python3
import csv
import gzip
import json
import statistics
import sys
from pathlib import Path

root = Path(sys.argv[1])
events = list(csv.DictReader((root / "results/events.tsv").open(), delimiter="\t"))
assert len(events) == 6, len(events)
window = (100, 600, 500)
runs = {}

def normalized(path):
    with gzip.open(path, "rt", errors="replace") as f:
        return "\n".join(
            line for line in f.read().splitlines()
            if not line.startswith(("MCYCLE_WINDOW ", "CALIPTRA_PROGRESS_HEARTBEAT "))
        )

for event in events:
    variant, repeat = event["variant"], int(event["repeat"])
    assert variant in ("baseline", "current") and repeat in (1, 2, 3)
    key = (variant, repeat)
    evidence = root / "runs" / f"cptra_ss_test_rom-r{repeat}-{variant}"
    fields = (evidence / "window.txt").read_text().strip().split()
    values = dict(item.split("=", 1) for item in fields[1:])
    observed = tuple(int(values[name]) for name in ("start", "end", "cycles"))
    assert observed == window, (key, observed)
    elapsed_ns = int(values["elapsed_ns"])
    assert elapsed_ns > 0
    hashes = {}
    for line in (evidence / "generated-hex.txt").read_text().splitlines():
        digest, filename = line.split(maxsplit=1)
        hashes[filename] = digest
    assert hashes, key
    result = json.loads((evidence / "result.json").read_text())
    assert result.get("passed") is False, (key, result.get("passed"))
    assert int(event["runner_exit"]) == 1, (key, event["runner_exit"])
    runs[key] = {
        "rate": 500 * 1_000_000_000 / elapsed_ns,
        "elapsed_ns": elapsed_ns,
        "hashes": hashes,
        "log": evidence / "sim.log.gz",
        "max_rss_kb": int((evidence / "peak-rss.txt").read_text().split()[-1]),
    }

assert len(runs) == 6
expected_hashes = next(iter(runs.values()))["hashes"]
expected_log = normalized(next(iter(runs.values()))["log"])
for key, row in runs.items():
    assert row["hashes"] == expected_hashes, (key, "firmware inputs differ")
    assert normalized(row["log"]) == expected_log, (key, "normalized logs differ")

summary = {
    "baseline_revision": "c014c0a7975a4b0b645ea34609c802be60a10f4a",
    "current_main_revision": "9b5fad2afb4104caa816b257d5bccc40f01b8c66",
    "case": "cptra_ss_test_rom",
    "window": {"start_mcycle": 100, "end_mcycle": 600, "cycles": 500},
    "external": {
        "qd_bfm": "8e34e0c6d20b6f84a5a975ba6e3de7ccd9b1dc2b",
        "caliptra_rtl": "49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e",
        "adams_bridge": "b77e3d899e828d626cfc2a0d26a6b5704cc121e0",
    },
    "samples": {},
    "all_firmware_inputs_identical": True,
    "all_normalized_logs_identical": True,
}
for variant, revision in (
    ("baseline", summary["baseline_revision"]),
    ("current", summary["current_main_revision"]),
):
    rates = [runs[(variant, repeat)]["rate"] for repeat in (1, 2, 3)]
    median = statistics.median(rates)
    summary["samples"][variant] = {
        "revision": revision,
        "cycles_per_second": rates,
        "median_cycles_per_second": median,
        "spread_percent": (max(rates) - min(rates)) / median * 100,
        "max_rss_kb": max(runs[(variant, repeat)]["max_rss_kb"] for repeat in (1, 2, 3)),
    }
main_rate = summary["samples"]["current"]["median_cycles_per_second"]
baseline_rate = summary["samples"]["baseline"]["median_cycles_per_second"]
summary["matched_speedup_percent"] = (main_rate / baseline_rate - 1) * 100
summary["historical_7_775_speedup_percent"] = (main_rate / 7.775 - 1) * 100
(root / "results/summary.json").write_text(json.dumps(summary, indent=2) + "\n")

lines = [
    "# Matched-window Caliptra result against the historical 7.775 cycles/s point",
    "",
    "Host: DAN-DESKTOP. One pinned CPU. Three interleaved samples per build.",
    "Test: cptra_ss_test_rom, fixed 100–600 mcycle window (500 cycles).",
    "The window deliberately stops before firmware completion; runner exit 1 and passed=false are expected.",
    "Builds use the same 4-state configuration, Caliptra RTL, QD-BFM, bridge, and deterministic ECC input source.",
    "",
    "| Build | Revision | Samples (cycles/s) | Median | Spread | Max RSS |",
    "|---|---|---:|---:|---:|---:|",
]
for variant in ("baseline", "current"):
    row = summary["samples"][variant]
    samples = ", ".join(f"{value:.3f}" for value in row["cycles_per_second"])
    lines.append(
        f'| {variant} | {row["revision"][:12]} | {samples} | '
        f'{row["median_cycles_per_second"]:.3f} | {row["spread_percent"]:.2f}% | '
        f'{row["max_rss_kb"]} KiB |'
    )
lines.extend([
    "",
    f'Matched current main vs c014 rerun: {summary["matched_speedup_percent"]:+.2f}%.',
    f'Current main vs historical 7.775 cycles/s point: {summary["historical_7_775_speedup_percent"]:+.2f}%.',
    "The matched same-job c014 median is the primary comparison; 7.775 is the original same-window reference point.",
    "All six generated firmware input manifests and normalized simulator logs matched.",
    "",
])
(root / "results/summary.md").write_text("\n".join(lines))
