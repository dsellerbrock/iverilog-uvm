#!/bin/bash
set -euo pipefail
cd /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm
E=evidence/ieee1800-audit-c12a-20261019/attempt-11-casex-x-control
IVL=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/iverilog
VVP=/tmp/a3-t2-batch-2026-10-19-6-local-r6/local-install/bin/vvp
sha256sum "$IVL" "$VVP" >"$E/toolchain-sha256.txt"
shasum -a 256 tests/1800_audit/c12/r12_05_casex_dyn.sv >"$E/source.sha256"
for g in 2017 2023; do
  o="$E/casex.$g"
  python3 scripts/run_with_timeout.py 180 -- "$IVL" -g"$g" -s m -o "$o.vvp" tests/1800_audit/c12/r12_05_casex_dyn.sv >"$o.compile.log" 2>&1
  python3 scripts/run_with_timeout.py 180 -- "$VVP" "$o.vvp" >"$o.run.log" 2>&1
  cat "$o.run.log"
  grep -Fq 'CX hit=2' "$o.run.log"
done
