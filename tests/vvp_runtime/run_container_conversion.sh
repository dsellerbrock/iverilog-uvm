#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
vvp=${VVP:-$repo_dir/vvp/vvp}
module_dir=${VPI_MODULE_DIR:-}
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/container-conversion.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ ! -x "$vvp" ]; then
    echo "error: VVP runtime is not executable: $vvp" >&2
    exit 2
fi
if [ -n "$module_dir" ] && [ ! -f "$module_dir/system.vpi" ]; then
    echo "error: system.vpi is not installed in: $module_dir" >&2
    exit 2
fi

run_vvp() {
    fixture=$1
    stdout=$2
    stderr=$3
    if [ -n "$module_dir" ]; then
        "$vvp" -M "$module_dir" -m system "$fixture" \
            > "$stdout" 2> "$stderr"
    else
        "$vvp" -m system "$fixture" > "$stdout" 2> "$stderr"
    fi
}

compare_output() {
    name=$1
    expected_stdout=$2
    expected_stderr=$3
    actual_stdout=$4
    actual_stderr=$5

    tr -d '\r' < "$expected_stdout" > "$work_dir/expected-stdout"
    tr -d '\r' < "$expected_stderr" > "$work_dir/expected-stderr"
    tr -d '\r' < "$actual_stdout" > "$work_dir/actual-stdout-normalized"
    tr -d '\r' < "$actual_stderr" > "$work_dir/actual-stderr-normalized"
    if ! cmp -s "$work_dir/expected-stdout" \
        "$work_dir/actual-stdout-normalized" ||
       ! cmp -s "$work_dir/expected-stderr" \
        "$work_dir/actual-stderr-normalized"; then
        echo "FAIL $name: output mismatch" >&2
        diff -u "$work_dir/expected-stdout" \
            "$work_dir/actual-stdout-normalized" >&2 || true
        diff -u "$work_dir/expected-stderr" \
            "$work_dir/actual-stderr-normalized" >&2 || true
        exit 1
    fi
}

cd "$repo_dir"
# The positive fixture is expected to run to completion (rc=0). Capture the
# status the same way run_rejected_image does rather than letting `set -e' kill
# the script: an unguarded failure here exits SILENTLY, with no FAIL line, no
# diff and no stderr, which is indistinguishable from the gate never reaching
# this step. That is exactly how this check failed on Linux while passing on
# macOS and MSYS2 -- undiagnosable from the CI log alone.
set +e
run_vvp tests/vvp_runtime/container_conversion.vvp \
    "$work_dir/positive.stdout" "$work_dir/positive.stderr"
positive_rc=$?
set -e
if [ "$positive_rc" -ge 128 ]; then
    echo "FAIL container conversion: VVP terminated by signal (rc=$positive_rc)" >&2
    cat "$work_dir/positive.stderr" >&2
    exit 1
fi
if [ "$positive_rc" -ne 0 ]; then
    echo "FAIL container conversion: expected rc=0, got rc=$positive_rc" >&2
    cat "$work_dir/positive.stderr" >&2
    exit 1
fi
compare_output "container conversion" \
    "$script_dir/container_conversion.stdout" \
    "$script_dir/container_conversion.stderr" \
    "$work_dir/positive.stdout" "$work_dir/positive.stderr"

run_rejected_image() {
    name=$1
    fixture=$2
    expected_rc=$3
    expected_stdout=$4
    expected_stderr=$5

    set +e
    run_vvp "$fixture" "$work_dir/$name.stdout" \
        "$work_dir/$name.stderr"
    rc=$?
    set -e

    if [ "$rc" -ge 128 ]; then
        echo "FAIL $name: VVP terminated by signal (rc=$rc)" >&2
        exit 1
    fi
    if [ "$rc" -ne "$expected_rc" ]; then
        echo "FAIL $name: expected rc=$expected_rc, got rc=$rc" >&2
        cat "$work_dir/$name.stderr" >&2
        exit 1
    fi
    compare_output "$name" "$expected_stdout" "$expected_stderr" \
        "$work_dir/$name.stdout" "$work_dir/$name.stderr"
}

run_rejected_image "container conversion malformed arity" \
    tests/vvp_runtime/container_conversion_malformed_arity.vvp 8 \
    "$script_dir/container_conversion_malformed_arity.stdout" \
    "$script_dir/container_conversion_malformed_arity.stderr"
run_rejected_image "container conversion malformed encoding" \
    tests/vvp_runtime/container_conversion_malformed_encoding.vvp 13 \
    "$script_dir/container_conversion_malformed_encoding.stdout" \
    "$script_dir/container_conversion_malformed_encoding.stderr"
run_rejected_image "container conversion malformed prototype" \
    tests/vvp_runtime/container_conversion_malformed_prototype.vvp 3 \
    "$script_dir/container_conversion_malformed_prototype.stdout" \
    "$script_dir/container_conversion_malformed_prototype.stderr"
run_rejected_image "strict stream runtime limit" \
    tests/vvp_runtime/container_conversion_strict_runtime_limit.vvp 1 \
    "$script_dir/container_conversion_strict_runtime_limit.stdout" \
    "$script_dir/container_conversion_strict_runtime_limit.stderr"

echo "PASS container conversion runtime/parser invariants (42/42)"
