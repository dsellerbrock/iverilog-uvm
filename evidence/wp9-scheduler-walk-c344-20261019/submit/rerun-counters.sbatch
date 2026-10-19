#!/usr/bin/env bash
#SBATCH --job-name=a5-wp9-queue-r2
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=03:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp9-scheduler-walk-c344-20261019-r2
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp9-scheduler-walk-c344-20261019-r2/logs/%x-%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp9-scheduler-walk-c344-20261019-r2
BUILT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp9-scheduler-walk-c344-20261019
BASE=c344d20197a569dea8936bad95de3d185b1e78dc
INPUT=$ROOT/input
SOURCE=$BUILT/source
INSTALL=$BUILT/install
RESULTS=$ROOT/results
LOGS=$ROOT/logs
mkdir -p "$ROOT"/{input,results,logs}
finish() {
  local rc=$?
  trap - EXIT
  printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
  touch "$RESULTS/DONE"
  exit "$rc"
}
trap finish EXIT

test "$(cat "$INPUT/measurement-base.txt")" = "$BASE"
(cd "$INPUT" && sha256sum --check SHA256SUMS) > "$RESULTS/input-checksums.txt"
test -x "$INSTALL/bin/iverilog"
test -x "$INSTALL/bin/vvp"
test -x "$INSTALL/bin/iverilog-vpi"
sha256sum "$INSTALL/bin/iverilog" "$INSTALL/bin/vvp" \
  "$INSTALL/bin/iverilog-vpi" "$INSTALL/lib/ivl/uvm_dpi.vpi" \
  > "$RESULTS/binaries.sha256"
export PATH="$INSTALL/bin:$PATH"
export IVERILOG="$INSTALL/bin/iverilog" IVERILOG_VPI="$INSTALL/bin/iverilog-vpi"
export VVP_BIN="$INSTALL/bin/vvp" UVM_DPI="$INSTALL/lib/ivl/uvm_dpi.vpi"
python3 "$INPUT/collect-stats.py" "$SOURCE" "$RESULTS/corpus" \
  > "$LOGS/corpus-counters.log" 2>&1
printf 'measurement_base=%s\nsource_commit=%s\nperf_stats=enabled\n' \
  "$BASE" "$BASE" > "$RESULTS/provenance.txt"
find "$RESULTS" -type f -print0 | sort -z | xargs -0 sha256sum > "$RESULTS/SHA256SUMS"
touch "$RESULTS/SUCCESS"
