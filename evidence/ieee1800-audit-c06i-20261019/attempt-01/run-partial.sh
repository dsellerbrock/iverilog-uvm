#!/bin/sh
# Excludes p06_08a until the lead replaces its known-failing event/null comparison.
set -u
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
OUT=evidence/ieee1800-audit-c06i-20261019/attempt-01
positives='p06_09a_vectors p06_10a_implicit p06_25a_param_types p06_25b_type_cmp'
negatives='n06_09_x_range n06_09_nonconst_range n06_10_default_nettype_none n06_10_gen_scope'
for g in 2017 2023; do
  for base in $positives; do
    exe="$OUT/$base.$g.vvp"
    if python3 scripts/run_with_timeout.py 45 -- "$IVL" -g"$g" -o "$exe" "tests/1800_audit/c06/$base.sv" > "$OUT/$base.$g.compile.log" 2>&1; then rc=0; else rc=$?; fi
    printf '\n== %s -g%s compile rc=%s ==\n' "$base" "$g" "$rc"
    cat "$OUT/$base.$g.compile.log"
    if [ "$rc" -eq 0 ]; then
      if python3 scripts/run_with_timeout.py 45 -- "$VVP" "$exe" > "$OUT/$base.$g.run.log" 2>&1; then rc=0; else rc=$?; fi
      printf 'run rc=%s\n' "$rc"
      cat "$OUT/$base.$g.run.log"
    fi
  done
  for base in $negatives; do
    if python3 scripts/run_with_timeout.py 45 -- "$IVL" -g"$g" -o "$OUT/$base.$g.vvp" "tests/1800_audit/c06/neg/$base.sv" > "$OUT/$base.$g.compile.log" 2>&1; then rc=0; else rc=$?; fi
    printf '\n== %s -g%s expected-error compile rc=%s ==\n' "$base" "$g" "$rc"
    cat "$OUT/$base.$g.compile.log"
  done
done
