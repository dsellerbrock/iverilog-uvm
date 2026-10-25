#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IVL=/tmp/a3-1800-audit-c06j-20261020-build/install/bin/iverilog
VVP=/tmp/a3-1800-audit-c06j-20261020-build/install/bin/vvp
TIMEOUT="$ROOT/scripts/run_with_timeout.py"
OUT="$(dirname "$0")/results"
for edition in 2017 2023; do
  mkdir -p "$OUT/$edition"
  python3 "$TIMEOUT" 60 -- "$IVL" "-g$edition" -s p21_05_2_write_2state \
    -o "$OUT/$edition/probe.vvp" "$ROOT/tests/1800_audit/c21/p21_05_2_write_2state.sv" \
    > "$OUT/$edition/compile.log" 2>&1
  echo 'COMPILE PASS' >> "$OUT/$edition/compile.log"
  (cd "$OUT/$edition" && python3 "$TIMEOUT" 60 -- "$VVP" probe.vvp > run.log 2>&1)
  echo 'RUN PASS' >> "$OUT/$edition/run.log"
  python3 - "$OUT/$edition/int.mem" "$OUT/$edition/enum.hex" <<'PY'
import pathlib, sys
def records(path):
    return [line.strip() for line in pathlib.Path(path).read_text().splitlines()
            if line.strip() and not line.lstrip().startswith('//')]
assert records(sys.argv[1]) == [
    '00000000000000000000000000000101',
    '00000000000000000000000000001010',
]
assert [value.lower() for value in records(sys.argv[2])] == ['a', '5']
PY
  echo 'OUTPUT CONTENTS PASS' >> "$OUT/$edition/run.log"
done
