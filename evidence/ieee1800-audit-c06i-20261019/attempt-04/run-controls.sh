#!/bin/sh
set -u
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
OUT=evidence/ieee1800-audit-c06i-20261019/attempt-04
for g in 2017 2023; do
  for base in r06_10_gen_ctrl_a r06_10_gen_ctrl_b r06_25_typedef_form r06_25_default_spec r06_25_inside_class; do
    exe="$OUT/$base.$g.vvp"
    if python3 scripts/run_with_timeout.py 45 -- "$IVL" -g"$g" -o "$exe" "tests/1800_audit/c06/$base.sv" > "$OUT/$base.$g.compile.log" 2>&1; then rc=0; else rc=$?; fi
    printf '\n== %s -g%s compile rc=%s ==\n' "$base" "$g" "$rc"
    head -8 "$OUT/$base.$g.compile.log"
    if [ "$rc" -eq 0 ]; then
      if python3 scripts/run_with_timeout.py 45 -- "$VVP" "$exe" > "$OUT/$base.$g.run.log" 2>&1; then rc=0; else rc=$?; fi
      printf 'run rc=%s\n' "$rc"
      cat "$OUT/$base.$g.run.log"
    fi
  done
done
