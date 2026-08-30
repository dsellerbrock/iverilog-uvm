#!/usr/bin/env bash
set -eu

test_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
iverilog_bin=$(command -v iverilog)
vvp_bin=$(command -v vvp)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/iverilog-vif-explicit-class.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

positive_source="$test_dir/positive.sv"
positive_image="$work_dir/positive.vvp"
positive_stdout="$work_dir/positive.stdout"
positive_stderr="$work_dir/positive.stderr"

if ! "$iverilog_bin" -g2012 \
     -s virtual_interface_explicit_class_positive \
     -o "$positive_image" "$positive_source" \
     >"$work_dir/positive.compile.stdout" 2>"$positive_stderr"; then
    echo "FAIL explicit virtual-interface class-property positive compile" >&2
    sed -n '1,20p' "$positive_stderr" >&2
    exit 1
fi

if ! "$vvp_bin" "$positive_image" >"$positive_stdout" 2>>"$positive_stderr"; then
    echo "FAIL explicit virtual-interface class-property runtime" >&2
    sed -n '1,20p' "$positive_stdout" >&2
    sed -n '1,20p' "$positive_stderr" >&2
    exit 1
fi

if ! grep -F -x -q \
     'PASSED virtual interface explicit class properties' "$positive_stdout"; then
    echo "FAIL explicit virtual-interface class-property output" >&2
    sed -n '1,20p' "$positive_stdout" >&2
    exit 1
fi

run_negative()
{
    name=$1
    top=$2
    expected=$3
    expected_total=$4
    source="$test_dir/$name.sv"
    stderr_file="$work_dir/$name.stderr"

    set +e
    "$iverilog_bin" -g2012 -s "$top" -o "$work_dir/$name.vvp" "$source" \
        >"$work_dir/$name.stdout" 2>"$stderr_file"
    status=$?
    set -e

    if [ "$status" -eq 0 ] || [ "$status" -ge 128 ]; then
        echo "FAIL $name: expected a normal compile rejection, got status $status" >&2
        sed -n '1,20p' "$stderr_file" >&2
        exit 1
    fi

    matched_count=$(grep -F -c -- "$expected" "$stderr_file" || true)
    total_count=$(grep -E -c ':[0-9]+: (error|sorry):' "$stderr_file" || true)
    if [ "$matched_count" -ne 1 ] || [ "$total_count" -ne "$expected_total" ]; then
        echo "FAIL $name: expected one focused diagnostic and $expected_total total, got $matched_count/$total_count" >&2
        sed -n '1,20p' "$stderr_file" >&2
        exit 1
    fi
}

run_negative known_noninterface \
    virtual_interface_explicit_class_known_noninterface \
    'error: virtual may only be used with interface types.' 1
run_negative missing_definition \
    virtual_interface_explicit_class_missing_definition \
    "error: Unknown interface type \`vif_explicit_interface_missing_if'." 1

echo "PASS explicit virtual-interface class-property focused tests (1 runtime, 2 negative)"
