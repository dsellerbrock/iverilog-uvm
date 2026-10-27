#!/bin/sh
set -u
ROOT=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
TEST=$ROOT/tests/1800_audit/c23/p23_04f_nested_module_scope.sv
OUT=$ROOT/evidence/ieee1800-audit-c23d-20261020/attempt-02
TIMEOUT=$ROOT/scripts/run_with_timeout.py
for g in 2017 2023; do
  exe="$OUT/nested-module-ports.$g.vvp"
  if python3 "$TIMEOUT" 45 -- "$IVL" -g"$g" -o "$exe" "$TEST" > "$OUT/nested-module-ports.$g.compile.log" 2>&1; then rc=0; else rc=$?; fi
  printf '\n== -g%s compile rc=%s ==\n' "$g" "$rc"
  cat "$OUT/nested-module-ports.$g.compile.log"
  if [ "$rc" -eq 0 ]; then
    if python3 "$TIMEOUT" 45 -- "$VVP" "$exe" > "$OUT/nested-module-ports.$g.run.log" 2>&1; then rc=0; else rc=$?; fi
    printf 'run rc=%s\n' "$rc"
    cat "$OUT/nested-module-ports.$g.run.log"
  fi
done
