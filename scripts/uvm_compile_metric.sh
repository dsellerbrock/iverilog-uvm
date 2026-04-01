#!/bin/sh
set -eu

timeout_s="${1:-15}"

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
workspace_root=$(CDPATH= cd -- "$repo_root/.." && pwd)

iverilog_bin="${IVERILOG_BIN:-$repo_root/install/bin/iverilog}"
uvm_root="${UVM_ROOT:-$workspace_root/accellera-official.uvm-core}"
tb_root="${UVM_TB_ROOT:-$workspace_root/uvm_testbench}"
log_file="${TMPDIR:-/tmp}/uvm_compile_metric.log"
out_file="${TMPDIR:-/tmp}/uvm_compile_metric.vvp"

rm -f "$log_file" "$out_file"

start_ts=$(date +%s)
set +e
ASAN_OPTIONS="${ASAN_OPTIONS:+$ASAN_OPTIONS:}detect_leaks=0" \
IVL_PERF_TRACE=1 timeout "$timeout_s" /usr/bin/time -f 'ELAPSED=%e\nMAXRSS=%M' \
  "$iverilog_bin" -g2012 \
  -I "$uvm_root/src" \
  -I "$tb_root" \
  -I "$tb_root/tb" \
  -I "$tb_root/rtl" \
  -o "$out_file" \
  "$uvm_root/src/uvm_pkg.sv" \
  "$tb_root/top.sv" >"$log_file" 2>&1
status=$?
set -e
end_ts=$(date +%s)

elapsed=$(grep '^ELAPSED=' "$log_file" | tail -n 1 | cut -d= -f2- || true)
maxrss=$(grep '^MAXRSS=' "$log_file" | tail -n 1 | cut -d= -f2- || true)
log_bytes=$(wc -c <"$log_file" | tr -d ' ')
last_perf=$(grep 'ivl-perf:' "$log_file" | tail -n 1 || true)
last_top_misses=$(grep 'ivl-perf-top-misses:' "$log_file" | tail -n 1 || true)
last_phase=$(grep 'ivl-perf-phase:' "$log_file" | tail -n 1 || true)
last_pending=$(grep 'ivl-perf-pending:' "$log_file" | tail -n 1 || true)

if [ -z "$elapsed" ]; then
  elapsed=$((end_ts - start_ts))
fi

printf 'timeout_s=%s exit=%s elapsed_s=%s maxrss_kb=%s log_bytes=%s\n' \
  "$timeout_s" "$status" "${elapsed:-unknown}" "${maxrss:-unknown}" "$log_bytes"

if [ -n "$last_perf" ]; then
  printf '%s\n' "$last_perf"
else
  printf 'ivl-perf: none\n'
fi

if [ -n "$last_top_misses" ]; then
  printf '%s\n' "$last_top_misses"
else
  printf 'ivl-perf-top-misses: none\n'
fi

if [ -n "$last_phase" ]; then
  printf '%s\n' "$last_phase"
else
  printf 'ivl-perf-phase: none\n'
fi

if [ -n "$last_pending" ]; then
  printf '%s\n' "$last_pending"
else
  printf 'ivl-perf-pending: none\n'
fi
