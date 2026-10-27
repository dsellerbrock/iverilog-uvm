#!/bin/bash
set -euo pipefail
cd /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm
D=tests/1800_audit/c12
E=evidence/ieee1800-audit-c12a-20261019/attempt-10-loop-jump-probes
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
sha256sum "$IVL" "$VVP" >"$E/toolchain-sha256.txt"
shasum -a 256 "$D/p12_07_loops.sv" "$D/p12_08_jumps.sv" "$D"/neg/n12_07_*.sv "$D"/neg/n12_08_*.sv >"$E/sources.sha256"
overall=0
positive() {
  local src=$1 top=$2 expected=$3 g o
  for g in 2017 2023; do
    o="$E/$top.$g"
    if python3 scripts/run_with_timeout.py 180 -- "$IVL" -g"$g" -s "$top" -o "$o.vvp" "$D/$src" >"$o.compile.log" 2>&1; then
      if python3 scripts/run_with_timeout.py 180 -- "$VVP" "$o.vvp" >"$o.run.log" 2>&1 && grep -Fq "$expected" "$o.run.log"; then
        printf '%s g%s PASS: %s\n' "$top" "$g" "$expected"
      else
        printf '%s g%s FAIL; output:\n' "$top" "$g"
        cat "$o.run.log"
        overall=1
      fi
    else
      rc=$?
      printf '%s g%s compile rc=%s\n' "$top" "$g" "$rc"
      head -5 "$o.compile.log"
      overall=1
    fi
  done
}
negative() {
  local src=$1 top=$2 g o
  for g in 2017 2023; do
    o="$E/$top.$g"
    if python3 scripts/run_with_timeout.py 180 -- "$IVL" -g"$g" -s "$top" -o "$o.vvp" "$D/neg/$src" >"$o.compile.log" 2>&1; then
      printf '%s g%s UNEXPECTEDLY ACCEPTED\n' "$top" "$g"
      overall=1
    else
      rc=$?
      printf '%s g%s rejected rc=%s\n' "$top" "$g" "$rc"
      head -3 "$o.compile.log"
    fi
  done
}
positive p12_07_loops.sv p12_07_loops 'RESULT pass=10 fail=0'
positive p12_08_jumps.sv p12_08_jumps 'RESULT pass=4 fail=0'
negative n12_08_break_outside_loop.sv n12_08_break_outside_loop
negative n12_08_continue_outside_loop.sv n12_08_continue_outside_loop
negative n12_08_return_outside_subroutine.sv n12_08_return_outside_subroutine
negative n12_08_break_cross_fork.sv n12_08_break_cross_fork
negative n12_07_for_scope_escape.sv n12_07_for_scope_escape
negative n12_07_foreach_index_write.sv n12_07_foreach_index_write
negative n12_07_foreach_too_many_indices.sv n12_07_foreach_too_many_indices
negative n12_08_return_missing_expression.sv n12_08_return_missing_expression
exit "$overall"
