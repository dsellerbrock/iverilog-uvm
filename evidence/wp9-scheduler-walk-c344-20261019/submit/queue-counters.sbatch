#!/usr/bin/env bash
#SBATCH --job-name=a5-wp9-queue-counters
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=03:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp9-scheduler-walk-c344-20261019
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp9-scheduler-walk-c344-20261019/logs/%x-%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp9-scheduler-walk-c344-20261019
BASE=c344d20197a569dea8936bad95de3d185b1e78dc
INPUT=$ROOT/input
SOURCE=$ROOT/source
INSTALL=$ROOT/install
RESULTS=$ROOT/results
LOGS=$ROOT/logs
mkdir -p "$ROOT"/{source,install,results,logs}
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
mkdir -p "$SOURCE/third_party/uvm/2020.2.0" "$SOURCE/third_party/uvm/2020.3.0" "$SOURCE/uvm-core"
tar -xzf "$INPUT/iverilog-uvm-c344-sourceonly.tar.gz" -C "$SOURCE" --strip-components=1
tar -xzf "$INPUT/uvm-2020.2.0.tar.gz" -C "$SOURCE/third_party/uvm/2020.2.0"
tar -xzf "$INPUT/uvm-2020.3.0.tar.gz" -C "$SOURCE/third_party/uvm/2020.3.0"
tar -xzf "$INPUT/uvm-core-78c0654.tar.gz" -C "$SOURCE/uvm-core"
(
  cd "$SOURCE"
  sh autoconf.sh
  ./configure --prefix="$INSTALL" --enable-libveriuser --enable-perf-stats \
    CFLAGS='-g -O2 -fno-omit-frame-pointer' \
    CXXFLAGS='-g -O2 -fno-omit-frame-pointer'
  timeout --signal=TERM --kill-after=30s 5400s make -j4
  timeout --signal=TERM --kill-after=30s 900s make install
  timeout --signal=TERM --kill-after=30s 900s make installuvm
) > "$LOGS/build.log" 2>&1

export PATH="$INSTALL/bin:$PATH"
export IVERILOG="$INSTALL/bin/iverilog" IVERILOG_VPI="$INSTALL/bin/iverilog-vpi"
export VVP_BIN="$INSTALL/bin/vvp" UVM_DPI="$INSTALL/lib/ivl/uvm_dpi.vpi"
python3 "$INPUT/collect-stats.py" "$SOURCE" "$RESULTS/corpus" \
  > "$LOGS/corpus-counters.log" 2>&1
printf 'measurement_base=%s\nsource_commit=%s\nperf_stats=enabled\n' \
  "$BASE" "$BASE" > "$RESULTS/provenance.txt"
find "$RESULTS" -type f -print0 | sort -z | xargs -0 sha256sum > "$RESULTS/SHA256SUMS"
touch "$RESULTS/SUCCESS"
