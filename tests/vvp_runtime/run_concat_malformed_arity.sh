#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
vvp=${VVP:-$repo_dir/vvp/vvp}
fixture=tests/vvp_runtime/concat_malformed_arity.vvp
expected_stdout=$script_dir/concat_malformed_arity.stdout
expected_stderr=$script_dir/concat_malformed_arity.stderr
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/concat-malformed-arity.XXXXXX")
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

if [ "$rc" -ne 2 ]; then
    echo "FAIL concat malformed arity: expected rc=2, got rc=$rc" >&2
    exit 1
fi

tr -d '\r' < "$expected_stdout" > "$work_dir/expected-stdout"
tr -d '\r' < "$expected_stderr" > "$work_dir/expected-stderr"
tr -d '\r' < "$work_dir/stdout" > "$work_dir/actual-stdout"
tr -d '\r' < "$work_dir/stderr" > "$work_dir/actual-stderr"
if ! cmp -s "$work_dir/expected-stdout" "$work_dir/actual-stdout" ||
   ! cmp -s "$work_dir/expected-stderr" "$work_dir/actual-stderr"; then
    echo "FAIL concat malformed arity: output mismatch" >&2
    diff -u "$work_dir/expected-stdout" "$work_dir/actual-stdout" >&2 || true
    diff -u "$work_dir/expected-stderr" "$work_dir/actual-stderr" >&2 || true
    exit 1
fi

echo "PASS concat malformed-arity invariants (2/2)"
