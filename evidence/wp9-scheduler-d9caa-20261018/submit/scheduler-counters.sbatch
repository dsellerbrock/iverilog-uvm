#!/usr/bin/env bash
#SBATCH --job-name=a5-wp9-scheduler-stats
#SBATCH --partition=verilog
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=03:00:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp9-scheduler-d9caa-20261018
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp9-scheduler-d9caa-20261018/logs/%x-%j.out

set -Eeuo pipefail
ROOT=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp9-scheduler-d9caa-20261018
SOURCE=$ROOT/source
INSTALL=$ROOT/install
INPUT=$ROOT/input
RESULTS=$ROOT/results
LOGS=$ROOT/logs
mkdir -p "$SOURCE" "$INSTALL" "$RESULTS" "$LOGS"
finish() {
  local rc=$?
  trap - EXIT
  printf '%s\n' "$rc" > "$RESULTS/job-exit-code"
  if (( rc == 0 )); then touch "$RESULTS/SUCCESS"; fi
  touch "$RESULTS/DONE"
  exit "$rc"
}
trap finish EXIT

test "$(cat "$INPUT/measurement-base.txt")" = d9caaaea5b410ed14e7ca14be828fc2f2c9fea44
(cd "$INPUT" && sha256sum --check source.sha256)
tar -xzf "$INPUT/source-d9caa.tar.gz" -C "$SOURCE"
{
  hostname
  uname -a
  cat "$INPUT/measurement-base.txt"
  sha256sum "$INPUT/source-d9caa.tar.gz"
} > "$RESULTS/provenance.txt"
(
  cd "$SOURCE"
  sh autoconf.sh
  ./configure --prefix="$INSTALL" --enable-perf-stats \
    CFLAGS='-g -O2 -fno-omit-frame-pointer' \
    CXXFLAGS='-g -O2 -fno-omit-frame-pointer'
  timeout --signal=TERM --kill-after=30s 5400s make -j4
  timeout --signal=TERM --kill-after=30s 900s make install
) > "$LOGS/build.log" 2>&1
PATH="$INSTALL/bin:$PATH" iverilog -g2012 \
  -o "$RESULTS/multi_clock.vvp" "$SOURCE/benchmarks/sim-hotspots/multi_clock.sv" \
  > "$LOGS/compile.log" 2>&1
/usr/bin/time -v -o "$RESULTS/multi_clock.time" \
  env IVL_PERF_STATS=1 "$INSTALL/bin/vvp" -n "$RESULTS/multi_clock.vvp" \
  > "$RESULTS/multi_clock.stdout" 2> "$RESULTS/multi_clock.stderr"
grep '^VVP_PERF_STATS ' "$RESULTS/multi_clock.stderr" > "$RESULTS/counters.json"
sha256sum "$RESULTS/provenance.txt" "$RESULTS/multi_clock.vvp" \
  "$RESULTS/multi_clock.stdout" "$RESULTS/multi_clock.stderr" \
  "$RESULTS/counters.json" "$RESULTS/multi_clock.time" > "$RESULTS/SHA256SUMS"
