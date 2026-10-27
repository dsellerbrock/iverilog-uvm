#!/bin/bash
set -euo pipefail
cd /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm
E=evidence/ieee1800-audit-c12a-20261019/attempt-08-corrected-cond-predicate-controls
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
overall=0
for spec in 'g4a_pattern_conditional r12_06_g4a_pattern_conditional g4a hit=5' 'g4b_guarded_pattern_conditional r12_06_g4b_guarded_pattern_conditional g4b hit=5' 'g4c_guarded_expression_conditional r12_06_g4c_guarded_expression_conditional g4c hit=5'; do
  read -r stem top expected <<<"$spec"
  src="tests/1800_audit/c12/r12_06_$stem.sv"
  for g in 2017 2023; do
    o="$E/$stem.$g"
    if python3 scripts/run_with_timeout.py 180 -- "$IVL" -g"$g" -s "$top" -o "$o.vvp" "$src" >"$o.compile.log" 2>&1; then
      printf 'g%s %s compile rc=0\n' "$g" "$stem"
      if python3 scripts/run_with_timeout.py 180 -- "$VVP" "$o.vvp" >"$o.run.log" 2>&1 && grep -F "$expected" "$o.run.log"; then
        :
      else
        printf 'g%s %s runtime/expectation failure\n' "$g" "$stem"
        cat "$o.run.log"
        overall=1
      fi
    else
      rc=$?
      printf 'g%s %s compile rc=%s\n' "$g" "$stem" "$rc"
      head -3 "$o.compile.log"
      overall=1
    fi
  done
done
exit "$overall"
