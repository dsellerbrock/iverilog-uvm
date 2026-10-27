#!/usr/bin/env bash
#SBATCH --job-name=a3-c07-qref
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c07-qref-20261020-01/logs/%x-%j.out

set -u
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c07-qref-20261020-01
TOOL=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin
SRC="$RUN_DIR/source/p07_10_3_ref.sv"
OUT="$RUN_DIR/results"
mkdir -p "$OUT"
printf 'Tool: '; "$TOOL/iverilog" -V | head -n 1
sha256sum "$TOOL/iverilog" "$TOOL/vvp" "$SRC"
for edition in 2017 2023; do
  binary="$OUT/p07_10_3_ref-${edition}.vvp"
  if timeout --signal=TERM --kill-after=2s 30s "$TOOL/iverilog" "-g$edition" -s p07_10_3_ref -o "$binary" "$SRC" >"$OUT/${edition}.compile.out" 2>"$OUT/${edition}.compile.err"; then
    compile_rc=0
  else
    compile_rc=$?
  fi
  printf '%s compile_rc=%s\n' "$edition" "$compile_rc"
  if [ "$compile_rc" -eq 0 ]; then
    if timeout --signal=TERM --kill-after=2s 30s "$TOOL/vvp" "$binary" >"$OUT/${edition}.run.out" 2>"$OUT/${edition}.run.err"; then
      run_rc=0
    else
      run_rc=$?
    fi
    printf '%s run_rc=%s\n' "$edition" "$run_rc"
    cat "$OUT/${edition}.run.out"
    cat "$OUT/${edition}.run.err"
  fi
done
