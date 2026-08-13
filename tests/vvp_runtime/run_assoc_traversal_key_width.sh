#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
vvp=${VVP:-$repo_dir/vvp/vvp}
fixture=$script_dir/assoc_traversal_key_width.vvp
expected=$script_dir/assoc_traversal_key_width.stdout
module_dir=${VPI_MODULE_DIR:-$repo_dir/local-install/lib/ivl}
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/assoc-key-width.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ ! -x "$vvp" ]; then
    echo "error: VVP runtime is not executable: $vvp" >&2
    exit 2
fi
if [ ! -f "$module_dir/system.vpi" ]; then
    echo "error: system.vpi is not installed in: $module_dir" >&2
    exit 2
fi

set +e
"$vvp" -M "$module_dir" -m system "$fixture" \
    > "$work_dir/stdout" 2> "$work_dir/stderr"
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
    echo "FAIL associative traversal key width: expected rc=0, got rc=$rc" >&2
    exit 1
fi
if [ -s "$work_dir/stderr" ]; then
    echo "FAIL associative traversal key width: expected empty stderr" >&2
    cat "$work_dir/stderr" >&2
    exit 1
fi
tr -d '\r' < "$expected" > "$work_dir/expected-normalized"
tr -d '\r' < "$work_dir/stdout" > "$work_dir/stdout-normalized"
if ! cmp -s "$work_dir/expected-normalized" "$work_dir/stdout-normalized"; then
    echo "FAIL associative traversal key width: stdout mismatch" >&2
    diff -u "$work_dir/expected-normalized" \
        "$work_dir/stdout-normalized" >&2 || true
    exit 1
fi

echo "PASS associative traversal key width invariant (1/1)"
