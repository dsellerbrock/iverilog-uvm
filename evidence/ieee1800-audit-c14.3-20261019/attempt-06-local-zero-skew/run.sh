#!/bin/bash
set -euo pipefail
ROOT=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm
SRC="$ROOT/tests/1800_audit/c14/p14_03_zero_output_skew.sv"
for edition in 2017 2023; do
  python3 "$ROOT/scripts/run_with_timeout.py" 90 -- /opt/homebrew/bin/iverilog "-g$edition" -s test -o "$PWD/$edition.vvp" "$SRC" >"$PWD/$edition-compile.log" 2>&1
  python3 "$ROOT/scripts/run_with_timeout.py" 90 -- /opt/homebrew/bin/vvp -n "$PWD/$edition.vvp" >"$PWD/$edition-run.log" 2>&1
  grep -qx PASSED "$PWD/$edition-run.log"
done
