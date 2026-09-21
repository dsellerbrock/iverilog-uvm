#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
vvp=${VVP:-$repo_dir/vvp/vvp}
fixture=tests/vvp_runtime/mixed_wait_malformed.vvp
expected_stdout=$script_dir/mixed_wait_malformed.stdout
expected_stderr=$script_dir/mixed_wait_malformed.stderr
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/mixed-wait-malformed.XXXXXX")
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

if [ "$rc" -ne 4 ]; then
    echo "FAIL mixed wait malformed bytecode: expected rc=4, got rc=$rc" >&2
    exit 1
fi

tr -d '\r' < "$expected_stdout" > "$work_dir/expected-stdout"
tr -d '\r' < "$expected_stderr" > "$work_dir/expected-stderr"
tr -d '\r' < "$work_dir/stdout" > "$work_dir/actual-stdout"
tr -d '\r' < "$work_dir/stderr" > "$work_dir/actual-stderr"
if ! cmp -s "$work_dir/expected-stdout" "$work_dir/actual-stdout" ||
   ! cmp -s "$work_dir/expected-stderr" "$work_dir/actual-stderr"; then
    echo "FAIL mixed wait malformed bytecode: output mismatch" >&2
    diff -u "$work_dir/expected-stdout" "$work_dir/actual-stdout" >&2 || true
    diff -u "$work_dir/expected-stderr" "$work_dir/actual-stderr" >&2 || true
    exit 1
fi

for case in valid outside stack; do
    fixture="tests/vvp_runtime/mixed_wait_recipe_$case.vvp"
    expected_rc=1
    if [ "$case" = valid ]; then expected_rc=0; fi
    set +e
    "$vvp" "$fixture" > "$work_dir/stdout" 2> "$work_dir/stderr"
    rc=$?
    set -e
    if [ "$rc" -ne "$expected_rc" ]; then
        echo "FAIL mixed wait recipe $case: expected rc=$expected_rc, got rc=$rc" >&2
        exit 1
    fi
    for stream in stdout stderr; do
        tr -d '\r' < "$script_dir/mixed_wait_recipe_$case.$stream" > "$work_dir/expected-$stream"
        tr -d '\r' < "$work_dir/$stream" > "$work_dir/actual-$stream"
        if ! cmp -s "$work_dir/expected-$stream" "$work_dir/actual-$stream"; then
            diff -u "$work_dir/expected-$stream" "$work_dir/actual-$stream" >&2 || true
            exit 1
        fi
    done
done

echo "PASS mixed wait recipe ABI invariants (7/7)"
