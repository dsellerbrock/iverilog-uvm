#!/bin/sh
set -eu
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
SRC=tests/1800_audit/c06/p06_11a_integer_real.sv
OUT=evidence/ieee1800-audit-c06h-20261019/attempt-03
for g in 2017 2023; do
  exe="$OUT/p06_11a_integer_real.$g.vvp"
  python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$exe" "$SRC" > "$OUT/p06_11a_integer_real.$g.compile.log" 2>&1
  python3 scripts/run_with_timeout.py 60 -- "$VVP" "$exe" > "$OUT/p06_11a_integer_real.$g.run.log" 2>&1
  printf 'g%s compile=0 run=0\n' "$g"
  cat "$OUT/p06_11a_integer_real.$g.run.log"
done
