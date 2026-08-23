#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
vvp=${VVP:-$repo_dir/vvp/vvp}
module_dir=${VPI_MODULE_DIR:-}
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/force-array-runtime.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ ! -x "$vvp" ]; then
    echo "error: VVP runtime is not executable: $vvp" >&2
    exit 2
fi
if [ -n "$module_dir" ] && [ ! -f "$module_dir/system.vpi" ]; then
    echo "error: system.vpi is not installed in: $module_dir" >&2
    exit 2
fi

run_case()
{
    name=$1
    fixture=$script_dir/$name.vvp
    expected=$script_dir/$name.stdout

    set +e
    if [ -n "$module_dir" ]; then
        "$vvp" -M "$module_dir" -m system "$fixture" \
            > "$work_dir/$name.stdout" 2> "$work_dir/$name.stderr"
    else
        "$vvp" -m system "$fixture" \
            > "$work_dir/$name.stdout" 2> "$work_dir/$name.stderr"
    fi
    rc=$?
    set -e

    if [ "$rc" -ne 0 ]; then
        echo "FAIL $name: expected rc=0, got rc=$rc" >&2
        cat "$work_dir/$name.stderr" >&2
        exit 1
    fi
    if [ -s "$work_dir/$name.stderr" ]; then
        echo "FAIL $name: expected empty stderr" >&2
        cat "$work_dir/$name.stderr" >&2
        exit 1
    fi
    tr -d '\r' < "$expected" > "$work_dir/$name.expected-normalized"
    tr -d '\r' < "$work_dir/$name.stdout" \
        > "$work_dir/$name.stdout-normalized"
    if ! cmp -s "$work_dir/$name.expected-normalized" \
        "$work_dir/$name.stdout-normalized"; then
        echo "FAIL $name: stdout mismatch" >&2
        diff -u "$work_dir/$name.expected-normalized" \
            "$work_dir/$name.stdout-normalized" >&2 || true
        exit 1
    fi
}

run_case force_array_alias
run_case force_array_extreme_offset
echo "PASS force-array alias and extreme-offset invariants (2/2)"
