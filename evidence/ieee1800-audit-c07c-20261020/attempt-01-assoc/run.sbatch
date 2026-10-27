#!/usr/bin/env bash
#SBATCH --job-name=a3-c07-assoc
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c07-assoc-20261020-01/logs/%x-%j.out

set -u
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c07-assoc-20261020-01
TOOL=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin
SRC="$RUN_DIR/source"
OUT="$RUN_DIR/results"
mkdir -p "$OUT"
printf 'Tool: '; "$TOOL/iverilog" -V | head -n 1
sha256sum "$TOOL/iverilog" "$TOOL/vvp"

run_case() {
  edition="$1" name="$2" top="$3" expectation="$4"
  binary="$OUT/${name}-${edition}.vvp"
  compile_out="$OUT/${name}-${edition}.compile.out"
  compile_err="$OUT/${name}-${edition}.compile.err"
  if timeout --signal=TERM --kill-after=2s 30s "$TOOL/iverilog" "-g$edition" -s "$top" -o "$binary" "$SRC/$name.sv" >"$compile_out" 2>"$compile_err"; then
    compile_rc=0
  else
    compile_rc=$?
  fi
  printf '%s %s compile_rc=%s expected=%s\n' "$edition" "$name" "$compile_rc" "$expectation"
  if [ "$expectation" = pass ] && [ "$compile_rc" -eq 0 ]; then
    if timeout --signal=TERM --kill-after=2s 30s "$TOOL/vvp" "$binary" >"$OUT/${name}-${edition}.run.out" 2>"$OUT/${name}-${edition}.run.err"; then
      printf '%s %s run_rc=0\n' "$edition" "$name"
      cat "$OUT/${name}-${edition}.run.out"
    else
      run_rc=$?
      printf '%s %s run_rc=%s\n' "$edition" "$name" "$run_rc"
    fi
  fi
}

for edition in 2017 2023; do
  run_case "$edition" p07_08_assoc p07_08_assoc pass
  run_case "$edition" n07_08_arg_index_type n07_08_arg_index_type reject
  run_case "$edition" n07_08_arg_fixed_array n07_08_arg_fixed_array reject
done
