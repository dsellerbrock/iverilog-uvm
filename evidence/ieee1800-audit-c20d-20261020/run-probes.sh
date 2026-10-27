#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IVL=/tmp/a3-1800-audit-c06j-20261020-build/install/bin/iverilog
VVP=/tmp/a3-1800-audit-c06j-20261020-build/install/bin/vvp
TIMEOUT="$ROOT/scripts/run_with_timeout.py"
OUT="$(dirname "$0")/results"
for edition in 2017 2023; do
  for probe in s_clog2 s_math1 s_math2 s_trig s_atan2_hypot s_hyper s_math_const; do
    image="$OUT/$probe-$edition.vvp"
    log="$OUT/$probe-$edition.log"
    python3 "$TIMEOUT" 60 -- "$IVL" "-g$edition" -o "$image" "$ROOT/tests/1800_audit/c20/s/$probe.sv" > "$log" 2>&1
    echo 'COMPILE PASS' >> "$log"
    python3 "$TIMEOUT" 60 -- "$VVP" "$image" >> "$log" 2>&1
    echo 'RUN PASS' >> "$log"
  done
done
