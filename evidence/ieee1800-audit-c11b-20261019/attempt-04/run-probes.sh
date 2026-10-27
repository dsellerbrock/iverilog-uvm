#!/bin/bash
set -u
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
D=tests/1800_audit/c11
E=evidence/ieee1800-audit-c11b-20261019/attempt-04
for src in r11_14_a_array_rw r11_14_b_stream_packed r11_14_c_stream_array r11_14_d_concat_rhs p11_04d_cat_inside_stream_reduced; do
  for g in 2017 2023; do
    base="$E/$src.$g"
    rm -f "$base.vvp"
    if python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$base.vvp" "$D/$src.sv" > "$base.compile.log" 2>&1; then rc=0; else rc=$?; fi
    printf '== %s g%s compile rc=%s ==\n' "$src" "$g" "$rc"
    cat "$base.compile.log"
    if [ "$rc" -eq 0 ]; then
      if python3 scripts/run_with_timeout.py 60 -- "$VVP" "$base.vvp" > "$base.run.log" 2>&1; then rc=0; else rc=$?; fi
      printf '== %s g%s run rc=%s ==\n' "$src" "$g" "$rc"
      cat "$base.run.log"
    fi
  done
done
