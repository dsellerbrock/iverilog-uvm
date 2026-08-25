#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
vvp=${VVP:-$repo_dir/vvp/vvp}
fixture=$script_dir/dist_unmarked_range_legacy.vvp
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dist-ir-compat.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ ! -x "$vvp" ]; then
    echo "error: VVP runtime is not executable: $vvp" >&2
    exit 2
fi

module_dir=
for candidate in "$repo_dir/vpi" "$repo_dir/local-install/lib/ivl" \
                 "$(dirname "$(command -v "$vvp")")/../lib/ivl"; do
    if [ -f "$candidate/system.vpi" ]; then
        module_dir=$candidate
        break
    fi
done
if [ -z "$module_dir" ]; then
    echo "error: cannot locate system.vpi for $vvp" >&2
    exit 2
fi

"$vvp" -M "$module_dir" -m system "$fixture" \
    > "$work_dir/legacy.stdout" 2> "$work_dir/legacy.stderr"
if [ -s "$work_dir/legacy.stderr" ]; then
    echo "FAIL historical unmarked dist IR: unexpected stderr" >&2
    cat "$work_dir/legacy.stderr" >&2
    exit 1
fi

counts=$(sed -n 's/^range=\([0-9][0-9]*\) four=\([0-9][0-9]*\)$/\1 \2/p' \
         "$work_dir/legacy.stdout")
set -- $counts
if [ "$#" -ne 2 ] || [ $(( $1 + $2 )) -ne 512 ] ||
   [ "$1" -lt 65 ] || [ "$1" -gt 145 ]; then
    echo "FAIL historical unmarked dist IR: expected aggregate :/ range weight" >&2
    cat "$work_dir/legacy.stdout" >&2
    exit 1
fi

# A stray close delimiter previously left build_z3_atom at the same cursor
# forever. Derive the malformed bytecode from the compatibility fixture so
# the only changed byte is the extra top-level ')' after the dist expression.
sed 's/(b c:4:32:s c:4:32:s))"/(b c:4:32:s c:4:32:s)))"/' \
    "$fixture" > "$work_dir/malformed.vvp"
"$vvp" -M "$module_dir" -m system "$work_dir/malformed.vvp" \
    > "$work_dir/malformed.stdout" 2> "$work_dir/malformed.stderr"

if ! cmp -s "$work_dir/legacy.stdout" "$work_dir/malformed.stdout"; then
    echo "FAIL malformed dist IR: recovery changed observable sampling" >&2
    diff -u "$work_dir/legacy.stdout" "$work_dir/malformed.stdout" >&2 || true
    exit 1
fi
expected='Warning: malformed constraint IR made no parser progress; skipping one byte (further similar warnings suppressed).'
actual=$(tr -d '\r' < "$work_dir/malformed.stderr")
if [ "$actual" != "$expected" ]; then
    echo "FAIL malformed dist IR: warning mismatch" >&2
    printf 'expected: %s\nactual: %s\n' "$expected" "$actual" >&2
    exit 1
fi

echo "PASS dist IR compatibility/recovery invariants (2/2)"
