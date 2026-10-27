#!/usr/bin/env bash
#SBATCH --job-name=a3-c20-covsys
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c20-covsys-20261020-01/logs/%x-%j.out
set -u
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c20-covsys-20261020-01
TOOL=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin
LIB=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/lib/ivl
SRC="$RUN_DIR/source/p20_14_cov.sv"
OUT="$RUN_DIR/results"
mkdir -p "$OUT"
printf 'Toolchain: '; "$TOOL/iverilog" -B "$LIB" -V
sha256sum "$TOOL/iverilog" "$TOOL/vvp" "$LIB/ivl" "$LIB/ivlpp" "$SRC"
for edition in 2017 2023; do
  binary="$OUT/p20_14_cov-$edition.vvp"
  if timeout --signal=TERM --kill-after=2s 30s "$TOOL/iverilog" -B "$LIB" "-g$edition" -s p20_14_cov -o "$binary" "$SRC" >"$OUT/p20_14_cov-$edition.compile.out" 2>"$OUT/p20_14_cov-$edition.compile.err"; then
    compile_rc=0
  else
    compile_rc=$?
  fi
  printf 'p20_14_cov-%s compile_rc=%s\n' "$edition" "$compile_rc"
  cat "$OUT/p20_14_cov-$edition.compile.out" "$OUT/p20_14_cov-$edition.compile.err"
  if [ "$compile_rc" -eq 0 ]; then
    if timeout --signal=TERM --kill-after=2s 30s "$TOOL/vvp" "$binary" >"$OUT/p20_14_cov-$edition.run.out" 2>"$OUT/p20_14_cov-$edition.run.err"; then
      run_rc=0
    else
      run_rc=$?
    fi
    printf 'p20_14_cov-%s run_rc=%s\n' "$edition" "$run_rc"
    cat "$OUT/p20_14_cov-$edition.run.out" "$OUT/p20_14_cov-$edition.run.err"
  fi
done
