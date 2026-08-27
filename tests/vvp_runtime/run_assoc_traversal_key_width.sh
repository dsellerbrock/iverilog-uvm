#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
vvp=${VVP:-$repo_dir/vvp/vvp}
fixture=$script_dir/assoc_traversal_key_width.vvp
expected=$script_dir/assoc_traversal_key_width.stdout
# Locate system.vpi the same way run_dist_ir_compat.sh does. Defaulting to
# $repo_dir/local-install hard-codes one workspace layout: CI configures
# without --prefix, so the modules land beside the installed vvp and
# local-install never exists. Fall back to the installed prefix.
module_dir=${VPI_MODULE_DIR:-}
if [ -z "$module_dir" ]; then
    for candidate in "$repo_dir/vpi" "$repo_dir/local-install/lib/ivl" \
                     "$(dirname "$(command -v "$vvp")")/../lib/ivl"; do
        if [ -f "$candidate/system.vpi" ]; then
            module_dir=$candidate
            break
        fi
    done
fi
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/assoc-key-width.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ ! -x "$vvp" ]; then
    echo "error: VVP runtime is not executable: $vvp" >&2
    exit 2
fi
if [ -z "$module_dir" ] || [ ! -f "$module_dir/system.vpi" ]; then
    echo "error: cannot locate system.vpi for $vvp" >&2
    exit 2
fi

set +e
"$vvp" -M "$module_dir" -m system "$fixture" \
    > "$work_dir/stdout" 2> "$work_dir/stderr"
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
    echo "FAIL associative traversal key width: expected rc=0, got rc=$rc" >&2
    exit 1
fi
if [ -s "$work_dir/stderr" ]; then
    echo "FAIL associative traversal key width: expected empty stderr" >&2
    cat "$work_dir/stderr" >&2
    exit 1
fi
tr -d '\r' < "$expected" > "$work_dir/expected-normalized"
tr -d '\r' < "$work_dir/stdout" > "$work_dir/stdout-normalized"
if ! cmp -s "$work_dir/expected-normalized" "$work_dir/stdout-normalized"; then
    echo "FAIL associative traversal key width: stdout mismatch" >&2
    diff -u "$work_dir/expected-normalized" \
        "$work_dir/stdout-normalized" >&2 || true
    exit 1
fi

echo "PASS associative traversal key width invariant (1/1)"
