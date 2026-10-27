#!/bin/sh
set -u
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
OUT=evidence/ieee1800-audit-c06k-20261020/attempt-01
TEST=tests/1800_audit/c06/p06_10b_generate_implicit_scope.sv
for g in 2017 2023; do
  exe="$OUT/p06_10b_generate_implicit_scope.$g.vvp"
  if python3 scripts/run_with_timeout.py 45 -- "$IVL" -g"$g" -o "$exe" "$TEST" > "$OUT/p06_10b_generate_implicit_scope.$g.compile.log" 2>&1; then rc=0; else rc=$?; fi
  printf '\n== -g%s compile rc=%s ==\n' "$g" "$rc"
  cat "$OUT/p06_10b_generate_implicit_scope.$g.compile.log"
  if [ "$rc" -eq 0 ]; then
    if python3 scripts/run_with_timeout.py 45 -- "$VVP" "$exe" > "$OUT/p06_10b_generate_implicit_scope.$g.run.log" 2>&1; then rc=0; else rc=$?; fi
    printf 'run rc=%s\n' "$rc"
    cat "$OUT/p06_10b_generate_implicit_scope.$g.run.log"
  fi
done
