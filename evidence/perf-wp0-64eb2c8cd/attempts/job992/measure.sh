#!/usr/bin/env bash
#SBATCH --job-name=a5-wp0-cal-281
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=01:00:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-calibrated-281d1bca/logs/measure-%j.out
#SBATCH --error=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-calibrated-281d1bca/logs/measure-%j.err
set -euo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-calibrated-281d1bca
CAND_SRC="$RUN/source-candidate"
REF_PREFIX=/home/dsell/toolchains/iverilog-a5-wp0-47bc28987caa
CAND_PREFIX=/home/dsell/toolchains/iverilog-a5-wp0-281d1bca-off
cd "$RUN"
sha256sum -c source.sha256
printf 'host=%s\n' "$(hostname)"
printf 'date_utc=%s\n' "$(date -u +%FT%TZ)"
printf 'kernel=%s\n' "$(uname -a)"
printf 'gcc=%s\n' "$(gcc --version | head -1)"
printf 'z3=%s\n' "$(z3 --version 2>/dev/null || echo unavailable)"
printf 'source_archive_hashes:\n'
sha256sum source-baseline.tar.gz source-candidate.tar.gz uvm-core.tar.gz
mkdir -p "$CAND_SRC/uvm-core"
tar -xzf source-candidate.tar.gz -C "$CAND_SRC"
tar -xzf uvm-core.tar.gz -C "$CAND_SRC/uvm-core"
test -x "$REF_PREFIX/bin/vvp"
test -x "$REF_PREFIX/bin/iverilog"
test -x "$REF_PREFIX/lib/ivl/uvm_dpi.vpi"
test ! -e "$CAND_PREFIX"
/usr/bin/time -v -o "$RUN/candidate-build.time" bash -c '
  set -euo pipefail
  cd "$1"
  sh autoconf.sh
  ./configure --prefix="$2" --enable-libveriuser
  make -j1
  make install
' _ "$CAND_SRC" "$CAND_PREFIX" >"$RUN/candidate-build.log" 2>&1
test -x "$CAND_PREFIX/bin/vvp"
grep -n 'VVP_PERF_STATS' "$CAND_SRC/vvp/config.h" > "$RUN/candidate-perf-config.txt"
if grep -Eq '^[[:space:]]*# *define VVP_PERF_STATS 1$' "$CAND_SRC/vvp/config.h"; then
  echo 'perf counters unexpectedly enabled in default candidate build' >&2
  exit 1
fi
if nm -C "$CAND_PREFIX/bin/vvp" | grep -q 'vvp_perf_stats_'; then
  echo 'perf counter symbols present in default candidate build' >&2
  exit 1
fi
sha256sum "$REF_PREFIX/bin/vvp" "$REF_PREFIX/bin/iverilog" \
  "$CAND_PREFIX/bin/vvp" "$CAND_PREFIX/bin/iverilog" \
  "$CAND_PREFIX/bin/iverilog-vpi" "$CAND_PREFIX/lib/ivl/uvm_dpi.vpi" \
  > "$RUN/binary.sha256"
{
  echo 'reference_vvp:'
  "$REF_PREFIX/bin/vvp" -V
  echo 'candidate_vvp:'
  "$CAND_PREFIX/bin/vvp" -V
} > "$RUN/tool-version.log" 2>&1
export PATH="$CAND_PREFIX/bin:$PATH"
export IVERILOG="$CAND_PREFIX/bin/iverilog"
export IVERILOG_VPI="$CAND_PREFIX/bin/iverilog-vpi"
export UVM_DPI="$CAND_PREFIX/lib/ivl/uvm_dpi.vpi"
unset IVL_PERF_STATS
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
failed = []
with open(sys.argv[2], "w", encoding="utf-8") as report:
    report.write("benchmark,ref_wall_median_s,ref_wall_spread_pct,ref_task_median_ms,ref_task_spread_pct,candidate_wall_median_s,candidate_wall_spread_pct,candidate_task_median_ms,candidate_task_spread_pct,ref_instructions,candidate_instructions\n")
    for name, benchmark in benchmarks.items():
        assert benchmark["status"] == "ok", (name, benchmark)
        assert benchmark["identical_all_runs"], name
        for sample in benchmark["samples"]:
            for label in ("reference", "candidate"):
                assert sample[label]["wall_seconds"] < 10, (name, label, sample[label]["wall_seconds"])
        row = []
        for label in ("reference", "candidate"):
            summary = benchmark["summary"][label]
            wall = summary["wall_seconds"]
            task = summary["task_clock_ms"]
            if label == "reference" and wall["spread_pct"] is not None and wall["spread_pct"] > 5:
                failed.append(f"{name}:{label}:wall={wall['spread_pct']:.3f}%")
            if label == "reference" and task["spread_pct"] is not None and task["spread_pct"] > 5:
                failed.append(f"{name}:{label}:task_clock={task['spread_pct']:.3f}%")
            row.extend([wall["median"], wall["spread_pct"], task["median"], task["spread_pct"]])
        ref = benchmark["summary"]["reference"]["instructions"]["median"]
        cand = benchmark["summary"]["candidate"]["instructions"]["median"]
        row.extend([ref, cand])
        report.write(name + "," + ",".join("" if v is None else f"{v:.6f}" if isinstance(v, float) else str(v) for v in row) + "\n")
    report.write(f"perf_stat_available={result['perf_stat_available']}\n")
    report.write(f"reference_instruction_count_available={all(b['summary']['reference']['instructions']['median'] is not None for b in benchmarks.values())}\n")
    report.write(f"candidate_instruction_count_available={all(b['summary']['candidate']['instructions']['median'] is not None for b in benchmarks.values())}\n")
    report.write("outputs_identical_all_18=true\n")
    report.write(f"reference_spread_at_most_5_percent={not failed}\n")
    for item in failed:
        report.write(f"SPREAD_FAILURE={item}\n")
if failed:
    raise SystemExit("reference spread exceeds 5%; see gate-summary.txt")
print(open(sys.argv[2], encoding="utf-8").read(), end="")
PY
sha256sum "$RUN/result.json" > "$RUN/result.sha256"
