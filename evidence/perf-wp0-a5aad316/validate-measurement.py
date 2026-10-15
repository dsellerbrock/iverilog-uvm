#!/usr/bin/env python3
"""Validate the pinned WP0 performance screen and five-pair measurement."""

import csv
import json
import sys


EXPECTED = {
    "rtl_pipe", "rtl_alu", "behav", "classq", "uvm_traffic", "randomize_z3",
    "randomize_dv_txn", "wide_vectors", "gate_strength", "multi_clock",
    "large_memory", "io_text", "waveform_vcd", "waveform_fst",
    "vpi_callbacks", "strings_aa_queue", "uvm_config_factory", "fork_heavy",
}


def main():
    source, stage = sys.argv[1:]
    result = json.load(open(source, encoding="utf-8"))
    benchmarks = result.get("benchmarks", {})
    failed = []
    if set(benchmarks) != EXPECTED:
        failed.append("benchmark_set_mismatch")
    expected_runs = 1 if stage == "screen" else 5
    if result.get("runs") != expected_runs:
        failed.append(f"run_count_mismatch:{result.get('runs')}")

    for name, benchmark in benchmarks.items():
        if benchmark.get("status") != "ok" or not benchmark.get("identical_all_runs"):
            failed.append(f"{name}:output_mismatch_or_error")
        if len(benchmark.get("samples", [])) != expected_runs:
            failed.append(f"{name}:sample_count_mismatch")
        if stage != "screen":
            for label in ("reference", "candidate"):
                hashes = {
                    sample.get(label, {}).get("output_sha256")
                    for sample in benchmark.get("samples", [])
                }
                if None in hashes or len(hashes) != 1:
                    failed.append(f"{name}:{label}:output_hash_varies_across_samples")
        for sample in benchmark.get("samples", []):
            if sample.get("identical") is not True:
                failed.append(f"{name}:sample_output_mismatch")
            for label in ("reference", "candidate"):
                wall = sample.get(label, {}).get("wall_seconds")
                if wall is None or wall >= 10:
                    failed.append(f"{name}:{label}:over_10s_or_missing_wall")

    print(f"stage={stage}")
    print(f"benchmarks={len(benchmarks)}")
    print(f"perf_stat_available={result.get('perf_stat_available')}")
    print(f"outputs_identical_all={not any('output_mismatch' in x for x in failed)}")
    print("every_runtime_sample_under_10s=" + str(not any("over_10s" in x for x in failed)))

    if stage == "screen":
        for failure in failed:
            print(f"GATE_FAILURE={failure}")
        if failed:
            return 1
        print("screen=PASS")
        return 0

    all_instructions = bool(benchmarks) and set(benchmarks) == EXPECTED and all(
        benchmark.get("summary", {}).get(label, {}).get("instructions", {}).get("median") is not None
        for benchmark in benchmarks.values()
        for label in ("reference", "candidate")
    )
    metric = "instructions" if all_instructions else "task_clock_ms"
    print(f"primary_metric={metric}")
    rows = []
    for name, benchmark in sorted(benchmarks.items()):
        summary = benchmark.get("summary", {})
        reference = summary.get("reference", {})
        candidate = summary.get("candidate", {})
        ref_metric = reference.get(metric, {})
        cand_metric = candidate.get(metric, {})
        if ref_metric.get("median") is None or ref_metric.get("spread_pct") is None:
            failed.append(f"{name}:reference:missing_{metric}")
        elif ref_metric["spread_pct"] > 5:
            failed.append(f"{name}:reference:{metric}_spread={ref_metric['spread_pct']:.3f}%")
        if cand_metric.get("median") is None:
            failed.append(f"{name}:candidate:missing_{metric}")
        ref_wall = reference.get("wall_seconds", {})
        cand_wall = candidate.get("wall_seconds", {})
        speedup = None
        if ref_metric.get("median") and cand_metric.get("median"):
            speedup = ref_metric["median"] / cand_metric["median"]
        rows.append({
            "benchmark": name,
            "ref_wall_median_s": ref_wall.get("median"),
            "ref_wall_spread_pct": ref_wall.get("spread_pct"),
            "candidate_wall_median_s": cand_wall.get("median"),
            "candidate_wall_spread_pct": cand_wall.get("spread_pct"),
            "primary_metric": metric,
            "ref_primary_median": ref_metric.get("median"),
            "ref_primary_spread_pct": ref_metric.get("spread_pct"),
            "candidate_primary_median": cand_metric.get("median"),
            "candidate_primary_spread_pct": cand_metric.get("spread_pct"),
            "primary_ratio_ref_over_candidate": speedup,
            "ref_instructions": reference.get("instructions", {}).get("median"),
            "candidate_instructions": candidate.get("instructions", {}).get("median"),
            "ref_max_rss_bytes": reference.get("max_rss_bytes", {}).get("max"),
            "candidate_max_rss_bytes": candidate.get("max_rss_bytes", {}).get("max"),
        })
    if failed:
        for failure in failed:
            print(f"GATE_FAILURE={failure}")
        return 1
    with open(source.replace(".json", ".csv"), "w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    print("reference_primary_spread_at_most_5_percent=True")
    print("measurement=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
