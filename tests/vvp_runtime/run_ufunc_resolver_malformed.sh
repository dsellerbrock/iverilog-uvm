#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
vvp=${VVP:-$repo_dir/vvp/vvp}
fixture=tests/vvp_runtime/ufunc_resolver_malformed.vvp
expected_stderr=$script_dir/ufunc_resolver_malformed.stderr
expected_stdout=$script_dir/ufunc_resolver_malformed.stdout
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/ufunc-resolver-malformed.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ ! -x "$vvp" ]; then
    echo "error: VVP runtime is not executable: $vvp" >&2
    exit 2
fi

cd "$repo_dir"
set +e
"$vvp" "$fixture" > "$work_dir/stdout" 2> "$work_dir/stderr"
rc=$?
set -e

if [ "$rc" -eq 0 ]; then
    echo "FAIL ufunc resolver malformed: expected a compile failure" >&2
    exit 1
fi
tr -d '\r' < "$expected_stderr" > "$work_dir/expected-stderr-normalized"
tr -d '\r' < "$work_dir/stderr" > "$work_dir/stderr-normalized"
if ! cmp -s "$work_dir/expected-stderr-normalized" "$work_dir/stderr-normalized"; then
    echo "FAIL ufunc resolver malformed: stderr mismatch" >&2
    diff -u "$work_dir/expected-stderr-normalized" \
        "$work_dir/stderr-normalized" >&2 || true
    exit 1
fi
tr -d '\r' < "$expected_stdout" > "$work_dir/expected-stdout-normalized"
tr -d '\r' < "$work_dir/stdout" > "$work_dir/stdout-normalized"
if ! cmp -s "$work_dir/expected-stdout-normalized" "$work_dir/stdout-normalized"; then
    echo "FAIL ufunc resolver malformed: stdout mismatch" >&2
    diff -u "$work_dir/expected-stdout-normalized" \
        "$work_dir/stdout-normalized" >&2 || true
    exit 1
fi

echo "PASS ufunc resolver malformed metadata invariants (2/2)"
