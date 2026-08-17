#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
vvp=${VVP:-$repo_dir/vvp/vvp}
fixture=$script_dir/vif_indexed_wait_malformed.vvp
expected=$script_dir/vif_indexed_wait_malformed.stderr
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/vif-indexed-wait.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ ! -x "$vvp" ]; then
    echo "error: VVP runtime is not executable: $vvp" >&2
    exit 2
fi

"$vvp" "$fixture" > "$work_dir/stdout" 2> "$work_dir/stderr"
if [ -s "$work_dir/stdout" ]; then
    echo "FAIL indexed VIF wait malformed bytecode: expected empty stdout" >&2
    exit 1
fi
tr -d '\r' < "$expected" > "$work_dir/expected-normalized"
tr -d '\r' < "$work_dir/stderr" > "$work_dir/stderr-normalized"
if ! cmp -s "$work_dir/expected-normalized" "$work_dir/stderr-normalized"; then
    echo "FAIL indexed VIF wait malformed bytecode: stderr mismatch" >&2
    diff -u "$work_dir/expected-normalized" \
        "$work_dir/stderr-normalized" >&2 || true
    exit 1
fi

echo "PASS indexed VIF wait malformed-bytecode invariants (3/3)"
