#!/usr/bin/env bash
#SBATCH --job-name=a5-wp0-cal-64eb
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=01:00:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-calibrated-64eb2c8cd/logs/measure-%j.out
#SBATCH --error=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-calibrated-64eb2c8cd/logs/measure-%j.err
set -euo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-calibrated-64eb2c8cd
CAND_SRC="$RUN/source-candidate"
REF_PREFIX=/home/dsell/toolchains/iverilog-a5-wp0-47bc28987caa
CAND_PREFIX=/home/dsell/toolchains/iverilog-a5-wp0-281d1bca-off
cd "$RUN"
sha256sum -c source.sha256
printf 'host=%s\n' "$(hostname)"
printf 'date_utc=%s\n' "$(date -u +%FT%TZ)"
printf 'kernel=%s\n' "$(uname -a)"
printf 'gcc=%s\n' "$(gcc --version | head -1)"
printf 'candidate_runtime_source_revision=281d1bca8 (vvp/configure files byte-identical through 64eb2c8cd)\n'
printf 'perf_config:\n'
cat candidate-perf-config.txt
sha256sum -c binary.sha256
mkdir -p "$CAND_SRC/uvm-core"
tar -xzf source-candidate.tar.gz -C "$CAND_SRC"
tar -xzf uvm-core.tar.gz -C "$CAND_SRC/uvm-core"
test -x "$REF_PREFIX/bin/vvp"
test -x "$REF_PREFIX/bin/iverilog"
test -x "$CAND_PREFIX/bin/vvp"
test -x "$CAND_PREFIX/bin/iverilog"
export PATH="$CAND_PREFIX/bin:$PATH"
export IVERILOG="$CAND_PREFIX/bin/iverilog"
export IVERILOG_VPI="$CAND_PREFIX/bin/iverilog-vpi"
export UVM_DPI="$CAND_PREFIX/lib/ivl/uvm_dpi.vpi"
unset IVL_PERF_STATS
bash "$CAND_SRC/benchmarks/sim-hotspots/run.sh" --json \
  "$REF_PREFIX/bin/vvp" "$CAND_PREFIX/bin/vvp" 1 \
  > "$RUN/screening.json" 2> "$RUN/screening.err"
python3 - "$RUN/screening.json" "$RUN/screening-summary.txt" <<'PY'
import json
import sys
expected = {
    "rtl_pipe", "rtl_alu", "behav", "classq", "uvm_traffic", "randomize_z3",
    "randomize_dv_txn", "wide_vectors", "gate_strength", "multi_clock",
    "large_memory", "io_text", "waveform_vcd", "waveform_fst",
    "vpi_callbacks", "strings_aa_queue", "uvm_config_factory", "fork_heavy",
}
with open(sys.argv[1], encoding="utf-8") as stream:
    result = json.load(stream)
assert set(result["benchmarks"]) == expected
for name, benchmark in result["benchmarks"].items():
    assert benchmark["status"] == "ok", (name, benchmark)
    assert benchmark["identical_all_runs"], name
    sample = benchmark["samples"][0]
    for label in ("reference", "candidate"):
        assert sample[label]["wall_seconds"] < 10, (name, label, sample[label])
with open(sys.argv[2], "w", encoding="utf-8") as report:
    report.write("18/18 outputs identical; every reference and candidate sample is under 10 s.\n")
PY
sha256sum "$RUN/screening.json" > "$RUN/screening.sha256"
bash "$CAND_SRC/benchmarks/sim-hotspots/run.sh" --json \
  "$REF_PREFIX/bin/vvp" "$CAND_PREFIX/bin/vvp" 5 \
  > "$RUN/result.json" 2> "$RUN/runner.err"
python3 - "$RUN/result.json" "$RUN/gate-summary.txt" <<'PY'
import json
import sys
expected = {
    "rtl_pipe", "rtl_alu", "behav", "classq", "uvm_traffic", "randomize_z3",
    "randomize_dv_txn", "wide_vectors", "gate_strength", "multi_clock",
    "large_memory", "io_text", "waveform_vcd", "waveform_fst",
    "vpi_callbacks", "strings_aa_queue", "uvm_config_factory", "fork_heavy",
}
with open(sys.argv[1], encoding="utf-8") as stream:
    result = json.load(stream)
benchmarks = result["benchmarks"]
assert set(benchmarks) == expected, (set(benchmarks), expected)
all_instructions = all(
    b["summary"][label]["instructions"]["median"] is not None
    for b in benchmarks.values() for label in ("reference", "candidate")
)
metric = "instructions" if all_instructions else "task_clock_ms"
failed = []
with open(sys.argv[2], "w", encoding="utf-8") as report:
    report.write(f"primary_metric={metric}\n")
    report.write("benchmark,ref_wall_median_s,ref_wall_spread_pct,ref_primary_median,ref_primary_spread_pct,candidate_wall_median_s,candidate_wall_spread_pct,candidate_primary_median,candidate_primary_spread_pct,ref_instructions,candidate_instructions\n")
    for name, benchmark in benchmarks.items():
        assert benchmark["status"] == "ok", (name, benchmark)
        assert benchmark["identical_all_runs"], name
        for sample in benchmark["samples"]:
            for label in ("reference", "candidate"):
                assert sample[label]["wall_seconds"] < 10, (name, label, sample[label]["wall_seconds"])
        row = []
        ref_summary = benchmark["summary"]["reference"]
        cand_summary = benchmark["summary"]["candidate"]
        for label, summary in (("reference", ref_summary), ("candidate", cand_summary)):
            wall = summary["wall_seconds"]
            primary = summary[metric]
            if primary["median"] is None or primary["spread_pct"] is None:
                failed.append(f"{name}:{label}:missing_{metric}")
            if label == "reference" and primary["spread_pct"] is not None and primary["spread_pct"] > 5:
                failed.append(f"{name}:reference:{metric}={primary['spread_pct']:.3f}%")
            row.extend([wall["median"], wall["spread_pct"], primary["median"], primary["spread_pct"]])
        row.extend([ref_summary["instructions"]["median"], cand_summary["instructions"]["median"]])
        report.write(name + "," + ",".join("" if v is None else f"{v:.6f}" if isinstance(v, float) else str(v) for v in row) + "\n")
    report.write(f"perf_stat_available={result['perf_stat_available']}\n")
    report.write(f"instruction_count_available={all_instructions}\n")
    report.write("outputs_identical_all_18=true\n")
    report.write(f"reference_primary_spread_at_most_5_percent={not failed}\n")
    for item in failed:
        report.write(f"GATE_FAILURE={item}\n")
if failed:
    raise SystemExit("primary-metric spread exceeds 5% or a required metric is missing")
print(open(sys.argv[2], encoding="utf-8").read(), end="")
PY
sha256sum "$RUN/result.json" > "$RUN/result.sha256"
