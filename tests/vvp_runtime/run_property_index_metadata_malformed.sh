#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
iverilog=${IVERILOG:-$(command -v iverilog)}
vvp=${VVP:-$(command -v vvp)}
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/property-index-metadata.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ ! -x "$iverilog" ] || [ ! -x "$vvp" ]; then
    echo "error: cannot locate executable Icarus compiler/runtime" >&2
    exit 2
fi

"$iverilog" -g2012 -s sv_class_unpacked_property_index_4state \
    -o "$work_dir/same.vvp" \
    "$repo_dir/ivtest/ivltests/sv_class_unpacked_property_index_4state.v"
python3 - "$work_dir/same.vvp" "$work_dir/malformed.vvp" <<'PY'
from pathlib import Path
import re
import sys

source, target = map(Path, sys.argv[1:])
text, count = re.subn(
    r'(%prop/index/check\s+)"1\|[^"\n]+"',
    r'\1"1|bad"',
    source.read_text(),
)
if count != 1:
    raise SystemExit(f"expected one property-index descriptor, found {count}")
target.write_text(text)
PY
printf 'PASSED\n' > "$work_dir/expected"
"$vvp" "$work_dir/malformed.vvp" +MALFORMED > "$work_dir/actual" \
    2> "$work_dir/stderr"
if [ -s "$work_dir/stderr" ] || ! cmp -s "$work_dir/expected" "$work_dir/actual"; then
    echo "FAIL malformed property-index descriptor did not return X for all cases" >&2
    cat "$work_dir/actual" "$work_dir/stderr" >&2
    exit 1
fi

echo "PASS malformed property-index descriptor (16/16 X results)"
