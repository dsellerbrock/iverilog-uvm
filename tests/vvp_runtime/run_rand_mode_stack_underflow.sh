#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
vvp=${VVP:-$repo_dir/vvp/vvp}
fixture=$script_dir/rand_mode_stack_underflow.vvp
expected=$script_dir/rand_mode_stack_underflow.stderr
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/rand-mode-underflow.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ ! -x "$vvp" ]; then
    echo "error: VVP runtime is not executable: $vvp" >&2
    exit 2
fi

set +e
"$vvp" "$fixture" > "$work_dir/stdout" 2> "$work_dir/stderr"
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
    echo "FAIL rand_mode stack underflow: expected rc=0, got rc=$rc" >&2
    exit 1
fi
if [ -s "$work_dir/stdout" ]; then
    echo "FAIL rand_mode stack underflow: expected empty stdout" >&2
    exit 1
fi
tr -d '\r' < "$expected" > "$work_dir/expected-normalized"
tr -d '\r' < "$work_dir/stderr" > "$work_dir/stderr-normalized"
if ! cmp -s "$work_dir/expected-normalized" "$work_dir/stderr-normalized"; then
    echo "FAIL rand_mode stack underflow: stderr mismatch" >&2
    diff -u "$work_dir/expected-normalized" \
        "$work_dir/stderr-normalized" >&2 || true
    exit 1
fi

echo "PASS rand_mode malformed-stack invariants (13/13)"
