#!/bin/bash
set -u
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
D=tests/1800_audit/c12
E=evidence/ieee1800-audit-c12a-20261019/attempt-06-if-guard-controls
for g in 2017 2023; do
 for f in "$D"/r12_06_g*.sv "$D/p12_05b_casex_unique_inside_pattern.sv"; do
  n=$(basename "$f" .sv); o="$E/$n.$g"
  if python3 scripts/run_with_timeout.py 30 -- "$IVL" -g"$g" -o "$o.vvp" "$f" > "$o.compile.log" 2>&1; then rc=0; else rc=$?; fi
  printf '== %s g%s compile rc=%s ==\n' "$n" "$g" "$rc"; head -4 "$o.compile.log"
  if [ "$rc" -eq 0 ]; then
   if python3 scripts/run_with_timeout.py 30 -- "$VVP" "$o.vvp" > "$o.run.log" 2>&1; then rc=0; else rc=$?; fi
   printf '== %s g%s run rc=%s ==\n' "$n" "$g" "$rc"; cat "$o.run.log"
  fi
 done
done
