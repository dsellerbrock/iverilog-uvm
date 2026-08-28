#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
vvp=${VVP:-$repo_dir/vvp/vvp}
fixture=$script_dir/array_slice_marshal_malformed.vvp
expected_stdout=$script_dir/array_slice_marshal_malformed.stdout
expected_stderr=$script_dir/array_slice_marshal_malformed.stderr
module_dir=${VPI_MODULE_DIR:-}
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/array-slice-marshal.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ ! -x "$vvp" ]; then
    echo "error: VVP runtime is not executable: $vvp" >&2
    exit 2
fi
if [ -z "$module_dir" ]; then
    for candidate in "$repo_dir/vpi" "$repo_dir/local-install/lib/ivl" \
                     "$(dirname "$(command -v "$vvp")")/../lib/ivl"; do
        if [ -f "$candidate/system.vpi" ]; then
            module_dir=$candidate
            break
        fi
    done
fi
if [ -z "$module_dir" ] || [ ! -f "$module_dir/system.vpi" ]; then
    echo "error: cannot locate system.vpi for $vvp" >&2
    exit 2
fi

set +e
"$vvp" -M "$module_dir" -m system "$fixture" \
    > "$work_dir/stdout" 2> "$work_dir/stderr"
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
    echo "FAIL array-slice marshal malformed IR: expected rc=0, got rc=$rc" >&2
    cat "$work_dir/stderr" >&2
    exit 1
fi
tr -d '\r' < "$expected_stdout" > "$work_dir/expected-stdout"
tr -d '\r' < "$work_dir/stdout" > "$work_dir/actual-stdout"
if ! cmp -s "$work_dir/expected-stdout" "$work_dir/actual-stdout"; then
    echo "FAIL array-slice marshal malformed IR: stdout mismatch" >&2
    diff -u "$work_dir/expected-stdout" "$work_dir/actual-stdout" >&2 || true
    exit 1
fi
tr -d '\r' < "$expected_stderr" > "$work_dir/expected-stderr"
tr -d '\r' < "$work_dir/stderr" > "$work_dir/actual-stderr"
if ! cmp -s "$work_dir/expected-stderr" "$work_dir/actual-stderr"; then
    echo "FAIL array-slice marshal malformed IR: stderr mismatch" >&2
    diff -u "$work_dir/expected-stderr" "$work_dir/actual-stderr" >&2 || true
    exit 1
fi

echo "PASS array-slice marshal textual-IR/recovery invariants (7/7)"
