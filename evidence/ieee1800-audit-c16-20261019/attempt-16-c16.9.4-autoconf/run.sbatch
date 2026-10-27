#!/usr/bin/env bash
#SBATCH --job-name=a3-c16-9-4-p16
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=3
#SBATCH --mem=4G
#SBATCH --time=00:30:00
#SBATCH --chdir=/home/dsell/slurm-runs/iverilog-uvm/A3/c16-9.4-20261019-16/source
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/A3/c16-9.4-20261019-16/logs/%x-%j.out
set -Eeuo pipefail
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/A3/c16-9.4-20261019-16
SRC="$RUN_DIR/source"
RESULTS="$RUN_DIR/results"
PREFIX="$RUN_DIR/install"
mkdir -p "$RESULTS"
printf 'job_id=%s\nhost=%s\nsource_commit=c31cbf1b52f1a39d5775f276e2340525a444a79e\nstarted=%s\n' "$SLURM_JOB_ID" "$(hostname)" "$(date -Is)" | tee "$RESULTS/metadata.txt"
sha256sum "$RUN_DIR/source.tar.gz" "$RUN_DIR/input/p16_09_04_global_clocking_funcs.sv" "$RUN_DIR/input/n16_09_04_no_global_clock.sv" | tee "$RESULTS/input.sha256"
cd "$SRC"
step() {
  label=$1; limit=$2; shift 2
  printf '\n=== %s (timeout %ss) ===\n' "$label" "$limit"
  set +e
  /usr/bin/time -v timeout --signal=TERM --kill-after=5s "${limit}s" "$@" > "$RESULTS/$label.log" 2>&1
  rc=$?
  set -e
  printf 'step_exit=%s\n' "$rc" | tee -a "$RESULTS/$label.log"
  tail -8 "$RESULTS/$label.log"
  test "$rc" -eq 0
}
step autoconf 120 autoconf
step configure 300 ./configure --prefix="$PREFIX" --enable-libveriuser
step build 1800 make -j3
step install 300 make install
IVERILOG="$PREFIX/bin/iverilog"
VVP="$PREFIX/bin/vvp"
printf 'iverilog=%s\nvvp=%s\n' "$IVERILOG" "$VVP" | tee "$RESULTS/toolchain.txt"
sha256sum "$IVERILOG" "$VVP" | tee "$RESULTS/compiler.sha256"
for edition in 2017 2023; do
  pos="$RUN_DIR/input/p16_09_04_global_clocking_funcs.sv"
  neg="$RUN_DIR/input/n16_09_04_no_global_clock.sv"
  set +e
  timeout --signal=TERM --kill-after=5s 120s "$IVERILOG" -B "$PREFIX/lib/ivl" -g"$edition" -gassertions -s test -o "$RESULTS/positive-$edition.vvp" "$pos" > "$RESULTS/positive-$edition.compile.log" 2>&1
  pos_rc=$?
  set -e
  printf 'positive_compile_exit=%s\n' "$pos_rc" | tee -a "$RESULTS/positive-$edition.compile.log"
  if test "$pos_rc" -eq 0; then
    set +e
    timeout --signal=TERM --kill-after=5s 120s "$VVP" -n "$RESULTS/positive-$edition.vvp" > "$RESULTS/positive-$edition.run.log" 2>&1
    run_rc=$?
    set -e
    printf 'positive_run_exit=%s\n' "$run_rc" | tee -a "$RESULTS/positive-$edition.run.log"
  fi
  set +e
  timeout --signal=TERM --kill-after=5s 120s "$IVERILOG" -B "$PREFIX/lib/ivl" -g"$edition" -gassertions -s test -o "$RESULTS/negative-$edition.vvp" "$neg" > "$RESULTS/negative-$edition.compile.log" 2>&1
  neg_rc=$?
  set -e
  printf 'negative_compile_exit=%s\n' "$neg_rc" | tee -a "$RESULTS/negative-$edition.compile.log"
  printf '\n=== edition %s results ===\n' "$edition"
  cat "$RESULTS/positive-$edition.compile.log"
  test ! -f "$RESULTS/positive-$edition.run.log" || cat "$RESULTS/positive-$edition.run.log"
  cat "$RESULTS/negative-$edition.compile.log"
done
printf 'finished=%s\n' "$(date -Is)" >> "$RESULTS/metadata.txt"
