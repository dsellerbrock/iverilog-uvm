#!/usr/bin/env bash
set -u
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
OUT=${OUT:-evidence/ieee1800-audit-c06d-20261019/attempt-01}
mkdir -p "$OUT"
echo "HOST: $(uname -a)"
echo "AUDIT CHECKOUT HEAD: $(git rev-parse HEAD)"
echo "COMPILER SOURCE COMMIT: b9441bafbdb0b6b7413c09e0381845e69481391b"
echo "IVERILOG: $IVL"
"$IVL" -V 2>&1 | head -2
shasum -a 256 "$IVL" "$VVP"
for g in 2017 2023; do
  for SRC in tests/1800_audit/c06/p06_20a_values.sv tests/1800_audit/c06/p06_20b_type_local_const.sv tests/1800_audit/c06/p06_20c_fwd_type_2023.sv tests/1800_audit/c06/neg/n06_20_*.sv; do
    base=$(basename "$SRC" .sv)
    exe="$OUT/$base.$g.vvp"
    log="$OUT/$base.$g.compile.log"
    run="$OUT/$base.$g.run.log"
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
