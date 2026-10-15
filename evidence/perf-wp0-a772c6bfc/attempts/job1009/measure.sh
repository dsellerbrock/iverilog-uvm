#!/usr/bin/env bash
#SBATCH --job-name=a5-wp0-cal-a772-r2
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:30:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-calibrated-a772c6bfc-20261014-r2/logs/%x-%j.out
#SBATCH --error=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-calibrated-a772c6bfc-20261014-r2/logs/%x-%j.err
set -euo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-calibrated-a772c6bfc-20261014-r2
CAND_SRC="$RUN/source"
REF_PREFIX=/home/dsell/toolchains/iverilog-a5-wp0-47bc28987caa
CAND_PREFIX=/home/dsell/toolchains/iverilog-a5-wp0-281d1bca-off
cd "$RUN"
printf 'candidate_benchmark_repository_revision=a772c6bfc\n' > source-manifest.txt
printf 'candidate_benchmark_repository_state=clean at staging\n' >> source-manifest.txt
printf 'uvm_core_submodule_revision=78c06547a2a0a29b3dc9dcafae62b75b2ff61544\n' >> source-manifest.txt
printf 'candidate_runtime_source_revision=281d1bca8 (runtime files unchanged through a772c6bfc)\n' >> source-manifest.txt
printf 'reference_runtime_source_revision=47bc28987caaece4b176f610212f170290b3039c\n' >> source-manifest.txt
(
  cd "$CAND_SRC"
  find . -type f -print0 | sort -z | xargs -0 sha256sum
) > source-files.sha256
(cd "$CAND_SRC" && sha256sum -c "$RUN/source-files.sha256")
{
  printf 'host=%s\n' "$(hostname)"
  printf 'date_utc=%s\n' "$(date -u +%FT%TZ)"
  printf 'kernel=%s\n' "$(uname -a)"
  gcc --version
  "$REF_PREFIX/bin/iverilog" -V
  "$REF_PREFIX/bin/vvp" -V
  "$CAND_PREFIX/bin/iverilog" -V
  "$CAND_PREFIX/bin/vvp" -V
  perf --version
  z3 --version
} > tool-version.log 2>&1
for binary in "$REF_PREFIX/bin/vvp" "$REF_PREFIX/bin/iverilog" \
              "$CAND_PREFIX/bin/vvp" "$CAND_PREFIX/bin/iverilog" \
              "$CAND_PREFIX/bin/iverilog-vpi" "$CAND_PREFIX/lib/ivl/uvm_dpi.vpi"; do
  test -x "$binary" || test -f "$binary"
done
sha256sum "$REF_PREFIX/bin/vvp" "$REF_PREFIX/bin/iverilog" \
  "$CAND_PREFIX/bin/vvp" "$CAND_PREFIX/bin/iverilog" \
  "$CAND_PREFIX/bin/iverilog-vpi" "$CAND_PREFIX/lib/ivl/uvm_dpi.vpi" \
  > binary.sha256
export PATH="$CAND_PREFIX/bin:$PATH"
export IVERILOG="$CAND_PREFIX/bin/iverilog"
export IVERILOG_VPI="$CAND_PREFIX/bin/iverilog-vpi"
export UVM_DPI="$CAND_PREFIX/lib/ivl/uvm_dpi.vpi"
unset IVL_PERF_STATS
RUNNER="$CAND_SRC/benchmarks/sim-hotspots/run.sh"
set +e
bash "$RUNNER" --json "$REF_PREFIX/bin/vvp" "$CAND_PREFIX/bin/vvp" 1 \
  > screen.json 2> screen.err
screen_rc=$?
set -e
shasum -a 256 screen.json screen.err > screen.sha256
if [[ "$screen_rc" -ne 0 ]]; then
  printf 'screen_exit_code=%s\n' "$screen_rc" > screen-gate.txt
  exit "$screen_rc"
fi
python3 - screen.json screen-gate.txt <<'PY'
import json, sys
expected = {
    "rtl_pipe", "rtl_alu", "behav", "classq", "uvm_traffic", "randomize_z3",
    "randomize_dv_txn", "wide_vectors", "gate_strength", "multi_clock",
    "large_memory", "io_text", "waveform_vcd", "waveform_fst",
    "vpi_callbacks", "strings_aa_queue", "uvm_config_factory", "fork_heavy",
}
result = json.load(open(sys.argv[1], encoding="utf-8"))
failed = []
if set(result["benchmarks"]) != expected:
    failed.append("benchmark_set_mismatch")
for name, bench in result["benchmarks"].items():
    if bench.get("status") != "ok" or not bench.get("identical_all_runs"):
        failed.append(f"{name}:output_mismatch_or_error")
    for sample in bench.get("samples", []):
        for label in ("reference", "candidate"):
            if sample[label]["wall_seconds"] >= 10:
                failed.append(f"{name}:{label}:over_10s")
with open(sys.argv[2], "w", encoding="utf-8") as out:
    out.write(f"screen_exit_code=0\nbenchmarks={len(result['benchmarks'])}\n")
    out.write(f"outputs_identical_all={not failed}\n")
    for item in failed:
        out.write(f"GATE_FAILURE={item}\n")
if failed:
    raise SystemExit("one-pair screen failed: " + ", ".join(failed))
print(open(sys.argv[2], encoding="utf-8").read(), end="")
PY
shasum -a 256 screen-gate.txt > screen-gate.sha256
set +e
bash "$RUNNER" --json "$REF_PREFIX/bin/vvp" "$CAND_PREFIX/bin/vvp" 5 \
  > result.json 2> runner.err
result_rc=$?
set -e
python3 - result.json gate-summary.txt "$result_rc" <<'PY'
import json, sys
expected = {
    "rtl_pipe", "rtl_alu", "behav", "classq", "uvm_traffic", "randomize_z3",
    "randomize_dv_txn", "wide_vectors", "gate_strength", "multi_clock",
    "large_memory", "io_text", "waveform_vcd", "waveform_fst",
    "vpi_callbacks", "strings_aa_queue", "uvm_config_factory", "fork_heavy",
}
with open(sys.argv[1], encoding="utf-8") as stream:
    result = json.load(stream)
benchmarks = result["benchmarks"]
failed = []
if int(sys.argv[3]) != 0:
    failed.append(f"runner_exit={sys.argv[3]}")
if set(benchmarks) != expected:
    failed.append("benchmark_set_mismatch")
all_instructions = bool(benchmarks) and set(benchmarks) == expected and all(
    benchmark["summary"][label]["instructions"]["median"] is not None
    for benchmark in benchmarks.values() for label in ("reference", "candidate")
)
metric = "instructions" if all_instructions else "task_clock_ms"
with open(sys.argv[2], "w", encoding="utf-8") as report:
    report.write(f"primary_metric={metric}\n")
    report.write("benchmark,ref_wall_median_s,ref_wall_spread_pct,ref_primary_median,ref_primary_spread_pct,candidate_wall_median_s,candidate_wall_spread_pct,candidate_primary_median,candidate_primary_spread_pct,ref_instructions,candidate_instructions\n")
    for name, benchmark in sorted(benchmarks.items()):
        if benchmark.get("status") != "ok" or not benchmark.get("identical_all_runs"):
            failed.append(f"{name}:output_mismatch_or_error")
            continue
        for sample in benchmark["samples"]:
            for label in ("reference", "candidate"):
                if sample[label]["wall_seconds"] >= 10:
                    failed.append(f"{name}:{label}:over_10s")
        ref_summary = benchmark["summary"]["reference"]
        cand_summary = benchmark["summary"]["candidate"]
        row = []
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
    report.write(f"outputs_identical_all_18={not any(item.endswith('output_mismatch_or_error') for item in failed)}\n")
    report.write(f"reference_primary_spread_at_most_5_percent={not failed}\n")
    for item in failed:
        report.write(f"GATE_FAILURE={item}\n")
if failed:
    raise SystemExit("full measurement gate failed: " + ", ".join(failed))
print(open(sys.argv[2], encoding="utf-8").read(), end="")
PY
shasum -a 256 result.json runner.err gate-summary.txt > result.sha256
