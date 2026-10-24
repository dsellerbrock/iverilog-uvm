#!/bin/sh
set -u
ROOT=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
OUT=$ROOT/evidence/ieee1800-audit-c21h-20261020/attempt-01
TIMEOUT=$ROOT/scripts/run_with_timeout.py
for g in 2017 2023; do
  mkdir -p "$OUT/$g"
  for name in noargs selectors; do
    test="$ROOT/tests/1800_audit/c21/p21_7_1_2_dumpvars_$name.sv"
    exe="$OUT/$g/$name.vvp"
    if python3 "$TIMEOUT" 45 -- "$IVL" -g"$g" -o "$exe" "$test" > "$OUT/$g/$name.compile.log" 2>&1; then rc=0; else rc=$?; fi
    printf '\n== %s -g%s compile rc=%s ==\n' "$name" "$g" "$rc"
    cat "$OUT/$g/$name.compile.log"
    if [ "$rc" -eq 0 ]; then
      if (cd "$OUT/$g" && python3 "$TIMEOUT" 45 -- "$VVP" "$exe") > "$OUT/$g/$name.run.log" 2>&1; then rc=0; else rc=$?; fi
      printf 'run rc=%s\n' "$rc"
      cat "$OUT/$g/$name.run.log"
    fi
  done
done
python3 "$OUT/verify.py" "$OUT"
