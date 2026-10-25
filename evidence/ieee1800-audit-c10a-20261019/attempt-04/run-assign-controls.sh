#!/bin/sh
set -u
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
OUT=evidence/ieee1800-audit-c10a-20261019/attempt-04
for g in 2017 2023; do
  for base in r10_06a_multi_rhs_update r10_06a_force_release_assign; do
    exe="$OUT/$base.$g.vvp"
    if python3 scripts/run_with_timeout.py 45 -- "$IVL" -g"$g" -o "$exe" "tests/1800_audit/c10/$base.sv" > "$OUT/$base.$g.compile.log" 2>&1; then rc=0; else rc=$?; fi
    printf '\n== %s -g%s compile rc=%s ==\n' "$base" "$g" "$rc"
    cat "$OUT/$base.$g.compile.log"
    if [ "$rc" -eq 0 ]; then
      if python3 scripts/run_with_timeout.py 45 -- "$VVP" "$exe" > "$OUT/$base.$g.run.log" 2>&1; then rc=0; else rc=$?; fi
      printf 'run rc=%s\n' "$rc"
      cat "$OUT/$base.$g.run.log"
    fi
  done
done
