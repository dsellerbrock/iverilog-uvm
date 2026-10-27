#!/usr/bin/env bash
set -u
B=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin
E=evidence/ieee1800-audit-c06a-20261019/diag2/A-split
for g in 2017 2023; do
  for m in diag_A_getc diag_A_idx diag_A_substr diag_A_compare diag_A_upper diag_A_copy; do
    out="$E/$m.$g"
    rm -f "$out.vvp"
    perl -e 'alarm 60; exec @ARGV' "$B/iverilog" -g"$g" -s "$m" -o "$out.vvp" tests/1800_audit/c06/r06_16_diag_A_split.sv >"$out.compile.log" 2>&1
    rc=$?
    echo "== $m -g$g compile_rc=$rc"
    cat "$out.compile.log"
    if [ -f "$out.vvp" ]; then
      perl -e 'alarm 60; exec @ARGV' "$B/vvp" -n "$out.vvp" >"$out.run.log" 2>&1
      echo "run_rc=$?"
      cat "$out.run.log"
    fi
  done
done
