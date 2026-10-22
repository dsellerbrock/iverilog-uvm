#!/usr/bin/env bash
#SBATCH --job-name=a3-c10-uconcat
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c10-uconcat-20261020-01/logs/%x-%j.out

set -u
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c10-uconcat-20261020-01
TOOL=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin
SRC="$RUN_DIR/source"
OUT="$RUN_DIR/results"
mkdir -p "$OUT"
printf 'Tool: '; "$TOOL/iverilog" -V | head -n 1
sha256sum "$TOOL/iverilog" "$TOOL/vvp" "$SRC"/*.sv
modules="p10_10_uconcat n10_10_fixed_size_mismatch n10_10_concat_no_context n10_10_nested_unpacked_concat n10_10_pattern_array_item_type"
for edition in 2017 2023; do
  for module in $modules; do
    binary="$OUT/${module}-${edition}.vvp"
    if timeout --signal=TERM --kill-after=2s 30s "$TOOL/iverilog" "-g$edition" -s "$module" -o "$binary" "$SRC/${module}.sv" >"$OUT/${module}-${edition}.compile.out" 2>"$OUT/${module}-${edition}.compile.err"; then
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
