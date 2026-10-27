#!/bin/bash
set -u
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
D=tests/1800_audit/c11
for g in 2017 2023; do
  b="evidence/ieee1800-audit-c11c-20261019/attempt-01-selects/p11_05a_select_len.$g"
  rm -f "$b.vvp"
  if python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$b.vvp" "$D/p11_05a_select_len.sv" > "$b.compile.log" 2>&1; then rc=0; else rc=$?; fi
  printf '== p11_05a_select_len g%s compile rc=%s ==\n' "$g" "$rc"; cat "$b.compile.log"
  if [ "$rc" -eq 0 ]; then
    if python3 scripts/run_with_timeout.py 60 -- "$VVP" "$b.vvp" > "$b.run.log" 2>&1; then rc=0; else rc=$?; fi
    printf '== p11_05a_select_len g%s run rc=%s ==\n' "$g" "$rc"; cat "$b.run.log"
  fi
  for f in "$D"/neg/n11_05_*.sv; do
    n=$(basename "$f" .sv); o="evidence/ieee1800-audit-c11c-20261019/attempt-01-selects/$n.$g"
    if python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o /dev/null "$f" > "$o.compile.log" 2>&1; then rc=0; else rc=$?; fi
    printf '== %s g%s compile rc=%s ==\n' "$n" "$g" "$rc"; cat "$o.compile.log"
  done
done
