#!/usr/bin/env bash
#SBATCH --job-name=a3-c07-assoc-split
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c07-assoc-20261020-03/logs/%x-%j.out

set -u
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c07-assoc-20261020-03
TOOL=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin
SRC="$RUN_DIR/source"
OUT="$RUN_DIR/results"
mkdir -p "$OUT"
printf 'Tool: '; "$TOOL/iverilog" -V | head -n 1
sha256sum "$TOOL/iverilog" "$TOOL/vvp"

run_case() {
  edition="$1" name="$2" top="$3"
  binary="$OUT/${name}-${edition}.vvp"
  if timeout --signal=TERM --kill-after=2s 30s "$TOOL/iverilog" "-g$edition" -s "$top" -o "$binary" "$SRC/$name.sv" >"$OUT/${name}-${edition}.compile.out" 2>"$OUT/${name}-${edition}.compile.err"; then
    compile_rc=0
  else
    compile_rc=$?
  fi
  printf '%s %s compile_rc=%s\n' "$edition" "$name" "$compile_rc"
  if [ "$compile_rc" -eq 0 ]; then
    if timeout --signal=TERM --kill-after=2s 30s "$TOOL/vvp" "$binary" >"$OUT/${name}-${edition}.run.out" 2>"$OUT/${name}-${edition}.run.err"; then
      printf '%s %s run_rc=0\n' "$edition" "$name"
    else
      run_rc=$?
      printf '%s %s run_rc=%s\n' "$edition" "$name" "$run_rc"
    fi
    cat "$OUT/${name}-${edition}.run.out"
  fi
}

for edition in 2017 2023; do
  run_case "$edition" a1_class_assoc_keys a1_class_assoc_keys
  run_case "$edition" a2_derived_assoc_key a2_derived_assoc_key
  run_case "$edition" a3_null_assoc_key a3_null_assoc_key
  run_case "$edition" a4_struct_assoc_key a4_struct_assoc_key
  run_case "$edition" a5_assoc_array_assignment a5_assoc_array_assignment
  run_case "$edition" a6_assoc_array_args a6_assoc_array_args
done
