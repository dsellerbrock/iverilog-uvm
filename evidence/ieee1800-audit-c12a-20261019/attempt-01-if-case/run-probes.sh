#!/bin/bash
set -u
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
D=tests/1800_audit/c12
E=evidence/ieee1800-audit-c12a-20261019/attempt-01-if-case
for g in 2017 2023; do
  o="$E/p12a.$g"
  if python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$o.vvp" "$D/p12_04a_if_case.sv" > "$o.compile.log" 2>&1; then rc=0; else rc=$?; fi
  printf '== p12_04a_if_case g%s compile rc=%s ==\n' "$g" "$rc"; head -3 "$o.compile.log"
  if [ "$rc" -eq 0 ]; then
    if python3 scripts/run_with_timeout.py 60 -- "$VVP" "$o.vvp" > "$o.run.log" 2>&1; then rc=0; else rc=$?; fi
    printf '== p12_04a_if_case g%s run rc=%s ==\n' "$g" "$rc"; cat "$o.run.log"
  fi
  for f in "$D"/neg/n12_0[45]_*.sv; do
    n=$(basename "$f" .sv); q="$E/$n.$g"
    if python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o /dev/null "$f" > "$q.compile.log" 2>&1; then rc=0; else rc=$?; fi
    printf '== %s g%s compile rc=%s ==\n' "$n" "$g" "$rc"; cat "$q.compile.log"
  done
done
