#!/usr/bin/env bash
#SBATCH --partition=verilog
#SBATCH --job-name=a5-wp0-icount
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=02:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-instr-ab-f9f8-20261014-r1/input
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-instr-ab-f9f8-20261014-r1/logs/%x-%j.out

set -euo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-instr-ab-f9f8-20261014-r1
BUILD_DIR=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp0-full-a5aad316-f9f8-20261014-r2
TOOLS="$RUN_DIR/tools/root"

finish() {
      local rc=$?
      trap - EXIT
      printf '%s\n' "$rc" >"$RUN_DIR/exit-status.txt"
      touch "$RUN_DIR/done"
      exit "$rc"
}
trap finish EXIT

sha256sum "$RUN_DIR"/tools/debs/*.deb >"$RUN_DIR/tools/packages.SHA256SUMS"
dpkg-deb -x "$RUN_DIR/tools/debs/valgrind_1%3a3.26.0-0ubuntu1_amd64.deb" "$TOOLS"
dpkg-deb -x "$RUN_DIR/tools/debs/libc6-dbg_2.43-2ubuntu2.4_amd64.deb" "$TOOLS"

VALGRIND="$TOOLS/usr/bin/valgrind"
VALGRIND_LIB="$TOOLS/usr/libexec/valgrind"
export VALGRIND_LIB
export PATH="$BUILD_DIR/install-off/bin:$PATH"
export IVERILOG="$BUILD_DIR/install-off/bin/iverilog"
export LC_ALL=C
"$VALGRIND" --version >"$RUN_DIR/tools/valgrind-version.txt"

bash "$RUN_DIR/input/callgrind-instruction-ab.sh" \
      "$BUILD_DIR/baseline-install/bin/vvp" \
      "$BUILD_DIR/install-off/bin/vvp" \
      "$IVERILOG" "$VALGRIND" "$VALGRIND_LIB" \
      "$RUN_DIR/input/behav.sv" "$RUN_DIR/results"
