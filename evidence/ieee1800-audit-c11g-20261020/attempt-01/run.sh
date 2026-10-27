#!/bin/sh
set -u
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
OUT=evidence/ieee1800-audit-c11g-20261020/attempt-01
TEST=tests/1800_audit/c11/p11_14_4_greedy_unbounded.sv
for g in 2017 2023; do
  exe="$OUT/p11_14_4_greedy_unbounded.$g.vvp"
  if python3 scripts/run_with_timeout.py 45 -- "$IVL" -g"$g" -o "$exe" "$TEST" > "$OUT/p11_14_4_greedy_unbounded.$g.compile.log" 2>&1; then rc=0; else rc=$?; fi
  printf '\n== -g%s compile rc=%s ==\n' "$g" "$rc"
  cat "$OUT/p11_14_4_greedy_unbounded.$g.compile.log"
  if [ "$rc" -eq 0 ]; then
    if python3 scripts/run_with_timeout.py 45 -- "$VVP" "$exe" > "$OUT/p11_14_4_greedy_unbounded.$g.run.log" 2>&1; then rc=0; else rc=$?; fi
    printf 'run rc=%s\n' "$rc"
    cat "$OUT/p11_14_4_greedy_unbounded.$g.run.log"
  fi
done
