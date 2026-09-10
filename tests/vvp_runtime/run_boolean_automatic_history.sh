#!/bin/sh
set -eu
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
vvp=${VVP:-$repo_dir/vvp/vvp}
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/boolean-history.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM
"$vvp" "$script_dir/boolean_automatic_history.vvp" > "$work_dir/stdout" 2> "$work_dir/stderr"
diff -u "$script_dir/boolean_automatic_history.stdout" "$work_dir/stdout"
if [ -s "$work_dir/stderr" ]; then
    cat "$work_dir/stderr" >&2
    exit 1
fi
echo "PASS automatic Boolean partial operand history and frame reuse"
