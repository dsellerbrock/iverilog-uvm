#!/usr/bin/env bash
set -Eeuo pipefail
D=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-caliptra-c7eb-20261015-r3/regression
REF=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp3-cast2-c7eb-20261015-r2/build/reference/install/bin
CAND=/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-caliptra-c7eb-20261015-r3/build/candidate/install/bin
cd "$D"
"$REF/iverilog" -g2012 -s sv_class_unpacked_property_index_4state \
    -o same.vvp sv_class_unpacked_property_index_4state.v
grep -q '%prop/index/check' same.vvp
"$REF/vvp" same.vvp > reference-valid.out 2>&1
"$CAND/vvp" same.vvp > candidate-valid.out 2>&1
cmp reference-valid.out candidate-valid.out
test "$(cat candidate-valid.out)" = PASSED
python3.12 - <<'PY'
from pathlib import Path
import re
source = Path("same.vvp")
text, count = re.subn(
    r'(%prop/index/check\s+)"1\|[^"\n]+"',
    r'\1"1|bad"', source.read_text())
if count != 1:
    raise SystemExit(f"expected one property-index descriptor, found {count}")
Path("malformed.vvp").write_text(text)
PY
"$REF/vvp" malformed.vvp +MALFORMED > reference-malformed.out 2>&1
"$CAND/vvp" malformed.vvp +MALFORMED > candidate-malformed.out 2>&1
cmp reference-malformed.out candidate-malformed.out
test "$(cat candidate-malformed.out)" = PASSED
printf 'PASS: 16 four-state inputs and 16 malformed-descriptor iterations match\n'
