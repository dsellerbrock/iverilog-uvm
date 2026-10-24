#!/bin/bash
set -u
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
D=tests/1800_audit/c12
E=evidence/ieee1800-audit-c12a-20261019/attempt-03-case-patterns
for g in 2017 2023; do
  o="$E/p12b.$g"
  if python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$o.vvp" "$D/p12_05b_casex_unique_inside_pattern.sv" > "$o.compile.log" 2>&1; then rc=0; else rc=$?; fi
  printf '== p12_05b g%s compile rc=%s ==\n' "$g" "$rc"; head -3 "$o.compile.log"
  if [ "$rc" -eq 0 ]; then
    if python3 scripts/run_with_timeout.py 60 -- "$VVP" "$o.vvp" > "$o.run.log" 2>&1; then rc=0; else rc=$?; fi
    printf '== p12_05b g%s run rc=%s ==\n' "$g" "$rc"; cat "$o.run.log"
  fi
done
