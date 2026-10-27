#!/bin/bash
set -u
D=tests/1800_audit/c20
E=evidence/ieee1800-audit-c20d-20261019/attempt-01-math-bits
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
for g in 2017 2023; do
  o="$E/p20f.$g"
  if ~/codex-supervisor/localrun 10 "$IVL" -g"$g" -o "$o.vvp" "$D/p20_08a_math_bits.sv" >"$o.compile.log" 2>&1; then
    echo "g$g compile rc=0"
    if ~/codex-supervisor/localrun 10 "$VVP" "$o.vvp" >"$o.run.log" 2>&1; then echo "g$g run rc=0"; rg '^(FAIL|RESULT)' "$o.run.log" || true; else rc=$?; echo "g$g run rc=$rc"; cat "$o.run.log"; fi
  else rc=$?; echo "g$g compile rc=$rc"; rg 'error:|sorry:|warning:' "$o.compile.log" || true; fi
done
