#!/usr/bin/env bash
#SBATCH --job-name=a3-c07-query
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c07-query-20261020-01/logs/%x-%j.out

set -u
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c07-query-20261020-01
TOOL=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin
SRC="$RUN_DIR/source"
OUT="$RUN_DIR/results"
mkdir -p "$OUT"
printf 'Tool: '; "$TOOL/iverilog" -V | head -n 1
sha256sum "$TOOL/iverilog" "$TOOL/vvp" "$SRC"/*.sv
for edition in 2017 2023; do
  binary="$OUT/p07_11_query-${edition}.vvp"
  if timeout --signal=TERM --kill-after=2s 30s "$TOOL/iverilog" "-g$edition" -s p07_11_query -o "$binary" "$SRC/p07_11_query.sv" >"$OUT/query-${edition}.compile.out" 2>"$OUT/query-${edition}.compile.err"; then
    compile_rc=0
  else
    compile_rc=$?
  fi
  printf 'query-%s compile_rc=%s\n' "$edition" "$compile_rc"
  if [ "$compile_rc" -eq 0 ]; then
    if timeout --signal=TERM --kill-after=2s 30s "$TOOL/vvp" "$binary" >"$OUT/query-${edition}.run.out" 2>"$OUT/query-${edition}.run.err"; then
      run_rc=0
    else
      run_rc=$?
    fi
    printf 'query-%s run_rc=%s\n' "$edition" "$run_rc"
    cat "$OUT/query-${edition}.run.out" "$OUT/query-${edition}.run.err"
  fi

  for negative in n07_11_nonintegral_assoc_query n07_11_dynamic_dimension_query; do
    binary="$OUT/${negative}-${edition}.vvp"
    if timeout --signal=TERM --kill-after=2s 30s "$TOOL/iverilog" "-g$edition" -s "$negative" -o "$binary" "$SRC/${negative}.sv" >"$OUT/${negative}-${edition}.compile.out" 2>"$OUT/${negative}-${edition}.compile.err"; then
      compile_rc=0
    else
      compile_rc=$?
    fi
    printf '%s-%s compile_rc=%s (expected nonzero)\n' "$negative" "$edition" "$compile_rc"
    cat "$OUT/${negative}-${edition}.compile.out" "$OUT/${negative}-${edition}.compile.err"
  done
done
