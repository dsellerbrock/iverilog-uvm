#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
vvp=${VVP:-$repo_dir/vvp/vvp}
fixture=$script_dir/prop_const_init_malformed.vvp
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/prop-const-init-malformed.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ ! -x "$vvp" ]; then
    echo "error: VVP runtime is not executable: $vvp" >&2
    exit 2
fi

set +e
"$vvp" "$fixture" > "$work_dir/stdout" 2> "$work_dir/stderr"
rc=$?
set -e

if [ "$rc" -ge 128 ]; then
    signal=$((rc - 128))
    echo "FAIL instance-constant guard underflow: runtime terminated by signal $signal (rc=$rc)" >&2
    exit 1
fi
if [ "$rc" -ne 1 ]; then
    echo "FAIL instance-constant guard underflow: expected rc=1, got rc=$rc" >&2
    exit 1
fi
if [ -s "$work_dir/stdout" ]; then
    echo "FAIL instance-constant guard underflow: expected empty stdout" >&2
    exit 1
fi

expected='prop_const_init_malformed.vvp:7: VVP error: %prop/const/init requires one class object on the object stack.'
printf '%s\n' "$expected" > "$work_dir/expected"
tr -d '\r' < "$work_dir/stderr" > "$work_dir/stderr-normalized"
if ! cmp -s "$work_dir/expected" "$work_dir/stderr-normalized"; then
    echo "FAIL instance-constant guard underflow: stderr mismatch" >&2
    diff -u "$work_dir/expected" "$work_dir/stderr-normalized" >&2 || true
    exit 1
fi

echo "PASS instance-constant guard malformed-stack invariant (1/1)"
