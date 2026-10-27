#!/usr/bin/env bash
#SBATCH --job-name=a3-c20f-bits-split
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c20f-bits-split-20261020-01/logs/%x-%j.out

set -u
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c20f-bits-split-20261020-01
TOOL=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin
LIB=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/lib/ivl
SRC="$RUN_DIR/source"
OUT="$RUN_DIR/results"
mkdir -p "$OUT"
printf 'Tool and helpers:\n'
"$TOOL/iverilog" -B "$LIB" -V
sha256sum "$TOOL/iverilog" "$TOOL/vvp" "$LIB/ivl" "$LIB/ivlpp" "$SRC"/*.sv
modules="p20_06_bits_b1 p20_06_bits_b2 p20_06_bits_b3 p20_06_bits_b4 p20_06_bits_b5"
for edition in 2017 2023; do
  for module in $modules; do
    binary="$OUT/${module}-${edition}.vvp"
    if timeout --signal=TERM --kill-after=2s 30s "$TOOL/iverilog" -B "$LIB" "-g$edition" -s "$module" -o "$binary" "$SRC/${module}.sv" >"$OUT/${module}-${edition}.compile.out" 2>"$OUT/${module}-${edition}.compile.err"; then
      compile_rc=0
    else
      compile_rc=$?
    fi
    printf '%s-%s compile_rc=%s\n' "$module" "$edition" "$compile_rc"
    cat "$OUT/${module}-${edition}.compile.out" "$OUT/${module}-${edition}.compile.err"
    if [ "$compile_rc" -eq 0 ]; then
      if timeout --signal=TERM --kill-after=2s 30s "$TOOL/vvp" "$binary" >"$OUT/${module}-${edition}.run.out" 2>"$OUT/${module}-${edition}.run.err"; then
        run_rc=0
      else
        run_rc=$?
      fi
      printf '%s-%s run_rc=%s\n' "$module" "$edition" "$run_rc"
      cat "$OUT/${module}-${edition}.run.out" "$OUT/${module}-${edition}.run.err"
    fi
  done
done
