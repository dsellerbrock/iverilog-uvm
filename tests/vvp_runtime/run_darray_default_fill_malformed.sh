#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
vvp=${VVP:-$repo_dir/vvp/vvp}
fixture=$script_dir/darray_default_fill_malformed.vvp
expected=$script_dir/darray_default_fill_malformed.stderr
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/darray-default-fill.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ ! -x "$vvp" ]; then
    echo "error: VVP runtime is not executable: $vvp" >&2
    exit 2
fi

set +e
"$vvp" "$fixture" > "$work_dir/stdout" 2> "$work_dir/stderr"
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
    echo "FAIL dynamic-array default fill malformed input: expected rc=0, got rc=$rc" >&2
    exit 1
fi
if [ -s "$work_dir/stdout" ]; then
    echo "FAIL dynamic-array default fill malformed input: expected empty stdout" >&2
    exit 1
fi
tr -d '\r' < "$expected" > "$work_dir/expected-normalized"
tr -d '\r' < "$work_dir/stderr" > "$work_dir/stderr-normalized"
if ! cmp -s "$work_dir/expected-normalized" "$work_dir/stderr-normalized"; then
    echo "FAIL dynamic-array default fill malformed input: stderr mismatch" >&2
    diff -u "$work_dir/expected-normalized" \
        "$work_dir/stderr-normalized" >&2 || true
    exit 1
fi

echo "PASS dynamic-array default-fill malformed-stack invariants (8/8)"
