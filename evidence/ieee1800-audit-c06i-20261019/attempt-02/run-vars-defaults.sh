#!/bin/sh
set -u
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
OUT=evidence/ieee1800-audit-c06i-20261019/attempt-02
for g in 2017 2023; do
  exe="$OUT/p06_08a_vars_defaults.$g.vvp"
  if python3 scripts/run_with_timeout.py 45 -- "$IVL" -g"$g" -o "$exe" tests/1800_audit/c06/p06_08a_vars_defaults.sv > "$OUT/p06_08a_vars_defaults.$g.compile.log" 2>&1; then rc=0; else rc=$?; fi
  printf '\n== p06_08a -g%s compile rc=%s ==\n' "$g" "$rc"
  cat "$OUT/p06_08a_vars_defaults.$g.compile.log"
  if [ "$rc" -eq 0 ]; then
    if python3 scripts/run_with_timeout.py 45 -- "$VVP" "$exe" > "$OUT/p06_08a_vars_defaults.$g.run.log" 2>&1; then rc=0; else rc=$?; fi
    printf 'run rc=%s\n' "$rc"
    cat "$OUT/p06_08a_vars_defaults.$g.run.log"
  fi
done
