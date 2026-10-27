#!/usr/bin/env bash
set -u
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
SRC=tests/1800_audit/c06/p06_24c_bitstream.sv
OUT=evidence/ieee1800-audit-c06c-20261019
mkdir -p "$OUT"
echo "HOST: $(uname -a)"
echo "SOURCE COMMIT: $(git rev-parse HEAD)"
echo "IVERILOG: $IVL"
"$IVL" -V 2>&1 | head -2
shasum -a 256 "$IVL" "$VVP"
for g in 2017 2023; do
  exe="$OUT/p06_24c_bitstream.$g.vvp"
  log="$OUT/p06_24c_bitstream.$g.compile.log"
  run="$OUT/p06_24c_bitstream.$g.run.log"
  rm -f "$exe"
  echo "== compile -g$g $SRC"
  python3 scripts/run_with_timeout.py 60 -- "$IVL" -g"$g" -o "$exe" "$SRC" >"$log" 2>&1
  rc=$?
  echo "compile_rc=$rc"
  cat "$log"
  if [ "$rc" -eq 0 ] && [ -f "$exe" ]; then
    echo "== run $exe"
    python3 scripts/run_with_timeout.py 60 -- "$VVP" "$exe" >"$run" 2>&1
    rc=$?
    echo "run_rc=$rc"
    cat "$run"
  else
    echo "run_rc=not-run"
  fi
done
