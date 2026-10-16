#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
iverilog=${IVERILOG:-$(command -v iverilog 2>/dev/null || true)}
vvp=${VVP:-$(command -v vvp 2>/dev/null || true)}
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/prop-index-check.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ -z "$iverilog" ] || [ -z "$vvp" ]; then
    echo "error: Icarus compiler and VVP runtime are required" >&2
    exit 2
fi

"$iverilog" -g2012 -s prop_index_check_predecode \
    -o "$work_dir/valid.vvp" "$script_dir/prop_index_check_predecode.sv"
if ! grep -q '%prop/index/check' "$work_dir/valid.vvp"; then
    echo "FAIL property-index test did not emit %prop/index/check" >&2
    exit 1
fi
if ! "$vvp" "$work_dir/valid.vvp" > "$work_dir/valid.out" 2>&1 \
        || ! grep -qx 'PASS property-index 4-state patterns (16 cases)' "$work_dir/valid.out"; then
    echo "FAIL property-index valid metadata cases" >&2
    cat "$work_dir/valid.out" >&2
    exit 1
fi

python3 - "$work_dir/valid.vvp" "$work_dir/malformed.vvp" <<'PY'
from pathlib import Path
import re
import sys

source, target = map(Path, sys.argv[1:])
text = source.read_text()
pattern = re.compile(r'(%prop/index/check\s+)"1\|[^"\n]+"')
text, count = pattern.subn(r'\1"1|bad"', text)
if count != 1:
    raise SystemExit(f"expected one 2-index property check, found {count}")
target.write_text(text)
PY

if ! "$vvp" "$work_dir/malformed.vvp" +MALFORMED > "$work_dir/malformed.out" 2>&1 \
        || ! grep -qx 'PASS property-index malformed metadata (16 cases)' "$work_dir/malformed.out"; then
    echo "FAIL property-index malformed metadata/pop cases" >&2
    cat "$work_dir/malformed.out" >&2
    exit 1
fi

echo "PASS property-index predecode and malformed metadata (32 cases)"
