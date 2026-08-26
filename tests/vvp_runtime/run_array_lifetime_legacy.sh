#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
vvp=${VVP:-$repo_dir/vvp/vvp}
fixture=$script_dir/array_lifetime_legacy.vvp
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/array-lifetime-legacy.XXXXXX")
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
    echo "FAIL legacy unmarked .array bytecode: expected rc=0, got rc=$rc" >&2
    cat "$work_dir/stderr" >&2
    exit 1
fi
if [ -s "$work_dir/stdout" ] || [ -s "$work_dir/stderr" ]; then
    echo "FAIL legacy unmarked .array bytecode: expected no output" >&2
    cat "$work_dir/stdout" >&2
    cat "$work_dir/stderr" >&2
    exit 1
fi

echo "PASS legacy unmarked .array lifetime compatibility"
