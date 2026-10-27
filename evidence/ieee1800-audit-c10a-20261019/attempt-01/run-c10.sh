#!/bin/sh
set -u
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
OUT=evidence/ieee1800-audit-c10a-20261019/attempt-01
positives='p10_03a_cont_assign p10_04a_proc_assign p10_06a_procont p10_06b_force_release'
negatives='n10_03_var_init_and_assign n10_03_var_proc_and_assign n10_03_var_two_assign n10_03_highz n10_03_interconnect_assign n10_06_assign_bitsel n10_06_force_var_bitsel'
for g in 2017 2023; do
  for base in $positives; do
    exe="$OUT/$base.$g.vvp"
    if python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$exe" "tests/1800_audit/c10/$base.sv" > "$OUT/$base.$g.compile.log" 2>&1; then rc=0; else rc=$?; fi
    printf '\n== %s -g%s compile rc=%s ==\n' "$base" "$g" "$rc"
    head -10 "$OUT/$base.$g.compile.log"
    if [ "$rc" -eq 0 ]; then
      if python3 scripts/run_with_timeout.py 60 -- "$VVP" "$exe" > "$OUT/$base.$g.run.log" 2>&1; then rc=0; else rc=$?; fi
      printf 'run rc=%s\n' "$rc"
      cat "$OUT/$base.$g.run.log"
    fi
  done
  for base in $negatives; do
    if python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$OUT/$base.$g.vvp" "tests/1800_audit/c10/neg/$base.sv" > "$OUT/$base.$g.compile.log" 2>&1; then rc=0; else rc=$?; fi
    printf '\n== %s -g%s expected-error compile rc=%s ==\n' "$base" "$g" "$rc"
    head -6 "$OUT/$base.$g.compile.log"
  done
done
