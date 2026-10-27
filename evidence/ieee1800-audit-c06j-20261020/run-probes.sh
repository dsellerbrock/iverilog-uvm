#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR=/tmp/a3-1800-audit-c06j-20261020-build/install
IVL="$BUILD_DIR/bin/iverilog"
VVP="$BUILD_DIR/bin/vvp"
OUT="${OUT_DIR:-$(dirname "$0")/results}"
mkdir -p "$OUT"
shasum -a 256 "$IVL" "$VVP" > "$OUT/tool-hashes.txt"
"$IVL" -V > "$OUT/version.txt" 2>&1
run_positive() {
  local edition="$1" name="$2" source="$3"
  local image="$OUT/${edition}-${name}.vvp" log="$OUT/${edition}-${name}.log"
  if python3 "$ROOT/scripts/run_with_timeout.py" 60 -- "$IVL" "-g$edition" -o "$image" "$ROOT/$source" > "$log" 2>&1; then
    echo 'COMPILE PASS' >> "$log"
  else
    echo "COMPILE FAIL rc=$?" >> "$log"
    return 0
  fi
  if python3 "$ROOT/scripts/run_with_timeout.py" 60 -- "$VVP" "$image" >> "$log" 2>&1; then
    echo 'RUN PASS' >> "$log"
  else
    echo 'RUN FAIL' >> "$log"
    return 1
  fi
}
run_negative() {
  local edition="$1" name="$2" source="$3" rc
  local image="$OUT/${edition}-${name}.vvp" log="$OUT/${edition}-${name}.log"
  if python3 "$ROOT/scripts/run_with_timeout.py" 60 -- "$IVL" "-g$edition" -o "$image" "$ROOT/$source" > "$log" 2>&1; then
    echo 'NEGATIVE COMPILE ACCEPT' >> "$log"
  else
    rc=$?
    echo "NEGATIVE COMPILE REJECT rc=$rc" >> "$log"
  fi
}
for edition in 2017 2023; do
  run_positive "$edition" assignment-compat tests/1800_audit/c06/p06_22c_assignment_compat.sv
  run_negative "$edition" implicit-integral-to-enum tests/1800_audit/c06/n06_22b_implicit_integral_to_enum.sv
  run_positive "$edition" matching-nettype-alias tests/1800_audit/c06/p06_22d_matching_nettype_alias.sv
  run_negative "$edition" nonmatching-nettypes tests/1800_audit/c06/n06_22c_nonmatching_nettypes.sv
done
