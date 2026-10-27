#!/bin/bash
set -euo pipefail
cd /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm
D=tests/1800_audit/c12
E=evidence/ieee1800-audit-c12a-20261019/attempt-07-no-guards
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
shasum -a 256 "$D/p12_05c_no_guards.sv" > "$E/source-corrected.sha256"
for g in 2017 2023; do
  o="$E/p12c.corrected.$g"
  if python3 scripts/run_with_timeout.py 180 -- "$IVL" -g"$g" -s p12c -o "$o.vvp" "$D/p12_05c_no_guards.sv" >"$o.compile.log" 2>&1; then
    printf 'g%s compile rc=0\n' "$g"
    if python3 scripts/run_with_timeout.py 180 -- "$VVP" "$o.vvp" >"$o.run.log" 2>&1; then
      cat "$o.run.log"
    else
      rc=$?
      printf 'g%s run rc=%s\n' "$g" "$rc"
      cat "$o.run.log"
    fi
  else
    rc=$?
    printf 'g%s compile rc=%s\n' "$g" "$rc"
    head -4 "$o.compile.log"
  fi
done
