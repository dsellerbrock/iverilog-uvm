#!/bin/bash
set -u
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
E=evidence/ieee1800-audit-c12a-20261019/attempt-04-match-filter-reduction
for g in 2017 2023; do
 for n in r12_06_match_filter r12_06_match_no_filter; do
  o="$E/$n.$g"
  if python3 scripts/run_with_timeout.py 30 -- "$IVL" -g"$g" -o "$o.vvp" "$E/$n.sv" > "$o.compile.log" 2>&1; then rc=0; else rc=$?; fi
  printf '== %s g%s compile rc=%s ==\n' "$n" "$g" "$rc"; cat "$o.compile.log"
  if [ "$rc" -eq 0 ]; then
   if python3 scripts/run_with_timeout.py 30 -- "$VVP" "$o.vvp" > "$o.run.log" 2>&1; then rc=0; else rc=$?; fi
   printf '== %s g%s run rc=%s ==\n' "$n" "$g" "$rc"; cat "$o.run.log"
  fi
 done
done
