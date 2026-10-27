#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IVL=/tmp/a3-1800-audit-c06j-20261020-build/install/bin/iverilog
VVP=/tmp/a3-1800-audit-c06j-20261020-build/install/bin/vvp
OUT="$(dirname "$0")/results"
mkdir -p "$OUT"
for edition in 2017 2023; do
  image="$OUT/$edition.vvp"
  log="$OUT/$edition.log"
  python3 "$ROOT/scripts/run_with_timeout.py" 60 -- "$IVL" "-g$edition" -o "$image" "$ROOT/tests/1800_audit/c20/p20_03_scaled_time_functions.sv" > "$log" 2>&1
  echo 'COMPILE PASS' >> "$log"
  python3 "$ROOT/scripts/run_with_timeout.py" 60 -- "$VVP" "$image" >> "$log" 2>&1
  echo 'RUN PASS' >> "$log"
done
