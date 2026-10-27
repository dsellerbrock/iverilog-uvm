#!/usr/bin/env bash
#SBATCH --job-name=a3-c11-lsp
#SBATCH --partition=verilog
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c11-lsp-20261020-01/logs/%x-%j.out
set -u
RUN_DIR=/home/dsell/slurm-runs/iverilog-uvm/a3/ieee1800-c11-lsp-20261020-01
TOOL=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin
LIB=/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/lib/ivl
SRC="$RUN_DIR/source"
OUT="$RUN_DIR/results"
mkdir -p "$OUT"
printf 'Toolchain: '; "$TOOL/iverilog" -B "$LIB" -V
sha256sum "$TOOL/iverilog" "$TOOL/vvp" "$LIB/ivl" "$LIB/ivlpp" "$SRC"/*.sv
run_case() {
  local module=$1 edition=$2 binary="$OUT/$1-$2.vvp"
  if timeout --signal=TERM --kill-after=2s 30s "$TOOL/iverilog" -B "$LIB" "-g$edition" -s "$module" -o "$binary" "$SRC/$module.sv" >"$OUT/$module-$edition.compile.out" 2>"$OUT/$module-$edition.compile.err"; then
    local compile_rc=0
  else
    local compile_rc=$?
  fi
  printf '%s-%s compile_rc=%s\n' "$module" "$edition" "$compile_rc"
  cat "$OUT/$module-$edition.compile.out" "$OUT/$module-$edition.compile.err"
  if [ "$compile_rc" -eq 0 ] && [ "$module" = p11_05_3_lsp ]; then
    if timeout --signal=TERM --kill-after=2s 30s "$TOOL/vvp" "$binary" >"$OUT/$module-$edition.run.out" 2>"$OUT/$module-$edition.run.err"; then
      local run_rc=0
    else
      local run_rc=$?
    fi
    printf '%s-%s run_rc=%s\n' "$module" "$edition" "$run_rc"
    cat "$OUT/$module-$edition.run.out" "$OUT/$module-$edition.run.err"
  fi
}
for edition in 2017 2023; do
  for module in p11_05_3_lsp n11_05_3_lsp_dynamic n11_05_3_lsp_overlap; do
    run_case "$module" "$edition"
  done
done
