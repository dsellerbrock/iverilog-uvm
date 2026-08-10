#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
vvp=${VVP:-$repo_dir/vvp/vvp}
template=$script_dir/static_property_binding.vvp.in
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/static-property-binding.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ ! -x "$vvp" ]; then
    echo "error: VVP runtime is not executable: $vvp" >&2
    exit 2
fi

run_failure()
{
    name=$1
    base_type=$2
    storage=$3
    expected=$4
    fixture=$work_dir/$name.vvp

    sed -e "s/@BASE_TYPE@/$base_type/g" \
        -e "s/@STORAGE@/$storage/g" "$template" > "$fixture"

    set +e
    ( set +e
      "$vvp" "$fixture" > "$work_dir/$name.stdout" \
          2> "$work_dir/$name.stderr"
      child_rc=$?
      exit "$child_rc"
    ) 2> /dev/null
    rc=$?
    set -e

    if [ "$rc" -ne 134 ]; then
        echo "FAIL $name: expected rc=134, got rc=$rc" >&2
        return 1
    fi
    if [ -s "$work_dir/$name.stdout" ]; then
        echo "FAIL $name: expected empty stdout" >&2
        return 1
    fi
    if ! cmp -s "$expected" "$work_dir/$name.stderr"; then
        echo "FAIL $name: stderr mismatch" >&2
        diff -u "$expected" "$work_dir/$name.stderr" >&2 || true
        return 1
    fi
    echo "PASS $name rc=134"
}

run_failure missing-label L8 v0xdeadbeef_0 \
    "$script_dir/static_property_binding_missing.stderr"
run_failure wrong-kind r v_vec8 \
    "$script_dir/static_property_binding_wrong_kind.stderr"
run_failure wrong-width L8 v_int32 \
    "$script_dir/static_property_binding_wrong_width.stderr"

echo "PASS static property binding invariants (3/3)"
