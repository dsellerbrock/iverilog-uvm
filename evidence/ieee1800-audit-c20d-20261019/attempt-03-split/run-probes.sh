#!/bin/bash
set +e
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
OUT=evidence/ieee1800-audit-c20d-20261019/attempt-03-split/logs
SOURCES=(tests/1800_audit/c20/s/s_*.sv)
[ "${#SOURCES[@]}" -eq 18 ] || { echo "expected 18 isolated sources, found ${#SOURCES[@]}"; exit 2; }
for edition in 2017 2023; do
  for src in "${SOURCES[@]}"; do
    name=$(basename "$src" .sv)
    base="$OUT/${name}.${edition}"
    echo "=== $name -g$edition ==="
    ~/codex-supervisor/localrun 10 "$IVL" "-g$edition" -o "$base.vvp" "$src" >"$base.compile.log" 2>&1
    compile_rc=$?
    echo "compile_rc=$compile_rc"
    cat "$base.compile.log"
    if [ "$compile_rc" -eq 0 ]; then
      ~/codex-supervisor/localrun 10 "$VVP" "$base.vvp" >"$base.run.log" 2>&1
      run_rc=$?
      echo "run_rc=$run_rc"
      cat "$base.run.log"
    fi
  done
done
