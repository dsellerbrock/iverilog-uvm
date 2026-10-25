#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IVL=/tmp/a3-1800-audit-c06j-20261020-build/install/bin/iverilog
VVP=/tmp/a3-1800-audit-c06j-20261020-build/install/bin/vvp
TIMEOUT="$ROOT/scripts/run_with_timeout.py"
OUT="$(dirname "$0")/results"
mkdir -p "$OUT"

if python3 "$TIMEOUT" 60 -- "$IVL" -g2017 -s test -I "$ROOT/ivtest" \
  -o "$OUT/functions-2017.vvp" "$ROOT/ivtest/ivltests/sv_timeunit_functions_2017.v" \
  > "$OUT/functions-2017.log" 2>&1; then
  echo 'UNEXPECTED: 2017 accepted 2023 timeunit functions' >> "$OUT/functions-2017.log"
  exit 1
else
  echo 'EXPECTED COMPILE REJECTION under -g2017' >> "$OUT/functions-2017.log"
fi

python3 "$TIMEOUT" 60 -- "$IVL" -g2023 -s test -I "$ROOT/ivtest" \
  -o "$OUT/functions-2023.vvp" "$ROOT/ivtest/ivltests/sv_timeunit_functions_2023.v" \
  > "$OUT/functions-2023.log" 2>&1
echo 'COMPILE PASS' >> "$OUT/functions-2023.log"
python3 "$TIMEOUT" 60 -- "$VVP" "$OUT/functions-2023.vvp" >> "$OUT/functions-2023.log" 2>&1
echo 'RUN PASS' >> "$OUT/functions-2023.log"

if python3 "$TIMEOUT" 60 -- "$IVL" -g2023 -s timeunit_functions_invalid -I "$ROOT/ivtest" \
  -o "$OUT/invalid-2023.vvp" "$ROOT/ivtest/ivltests/sv_timeunit_functions_invalid_2023.v" \
  > "$OUT/invalid-2023.log" 2>&1; then
  echo 'UNEXPECTED: invalid hierarchical argument was accepted' >> "$OUT/invalid-2023.log"
  exit 1
else
  echo 'EXPECTED COMPILE REJECTION for non-hierarchical argument' >> "$OUT/invalid-2023.log"
fi
