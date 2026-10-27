#!/usr/bin/env bash
set -u
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
OUT=evidence/ieee1800-audit-c06c-20261019
mkdir -p "$OUT"
echo "HOST: $(uname -a)"
echo "SOURCE COMMIT: $(git rev-parse HEAD)"
echo "IVERILOG: $IVL"
"$IVL" -V 2>&1 | head -2
shasum -a 256 "$IVL" "$VVP"
for g in 2017 2023; do
  for SRC in tests/1800_audit/c06/p06_24e_task_invalid.sv tests/1800_audit/c06/p06_24f_nonsingular.sv; do
    base=$(basename "$SRC" .sv)
    exe="$OUT/$base.$g.vvp"
    log="$OUT/$base.$g.compile.log"
    run="$OUT/$base.$g.run.log"
    rm -f "$exe"
    echo "== compile -g$g $SRC"
    python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$exe" "$SRC" >"$log" 2>&1
    rc=$?
    echo "compile_rc=$rc"
    cat "$log"
    if [ -f "$exe" ]; then
      echo "== run $exe"
      python3 scripts/run_with_timeout.py 60 -- "$VVP" "$exe" >"$run" 2>&1
      rc=$?
      echo "run_rc=$rc"
      cat "$run"
    else
      echo "run_rc=not-run"
    fi
  done
done
