#!/usr/bin/env bash
#SBATCH --job-name=a5-wp0-verify
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:30:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-stats-current-verify-47bc-20261014-r2/logs/verify-%j.out
#SBATCH --error=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-stats-current-verify-47bc-20261014-r2/logs/verify-%j.err
set -euo pipefail
RUN=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-stats-current-verify-47bc-20261014-r2
BASE=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-baseline-47bc-20261014-r1/install
SRC="$RUN/source/tree"
cd "$RUN"
tar -xzf "$RUN/source.tar.gz" -C "$SRC"
/usr/bin/time -v -o "$RUN/build.time" bash -c '
set -euo pipefail
cd "$1"
sh autoconf.sh
./configure --prefix="$2/install" --enable-libveriuser --enable-perf-stats
make -j1
make install
' _ "$SRC" "$RUN"
test -x "$RUN/install/bin/iverilog"
test -x "$RUN/install/bin/vvp"
grep -Eq '^[[:space:]]*# *define VVP_PERF_STATS 1$' "$SRC/vvp/config.h"
sha256sum "$BASE/bin/vvp" "$RUN/install/bin/vvp" "$RUN/install/bin/iverilog" \
      "$RUN/install/bin/iverilog-vpi" "$BASE/lib/ivl/uvm_dpi.vpi" >"$RUN/binary.sha256"
bash "$SRC/benchmarks/sim-hotspots/test_perf_stats.sh" \
      "$BASE/bin/iverilog" "$BASE/bin/vvp" "$RUN/install/bin/vvp" \
      >"$RUN/perf-stats-smoke.log" 2>&1
export IVERILOG="$RUN/install/bin/iverilog"
export IVERILOG_VPI="$RUN/install/bin/iverilog-vpi"
export UVM_DPI="$BASE/lib/ivl/uvm_dpi.vpi"
unset IVL_PERF_STATS
bash "$SRC/benchmarks/sim-hotspots/run.sh" --json \
      "$BASE/bin/vvp" "$RUN/install/bin/vvp" 1 >"$RUN/result.json" 2>"$RUN/runner.err"
python3 - "$RUN/result.json" <<'PY'
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
for name, benchmark in benchmarks.items():
    assert benchmark["status"] == "ok", (name, benchmark)
    assert benchmark["identical_all_runs"], name
    for sample in benchmark["samples"]:
        for label in ("reference", "candidate"):
            assert sample[label]["wall_seconds"] < 10, (
                name, label, sample[label]["wall_seconds"]
            )
print("All 18 workloads passed strict output checks under 10 seconds.")
print("perf_stat_available:", result["perf_stat_available"])
PY
