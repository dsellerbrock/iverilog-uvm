#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
vvp=${VVP:-$repo_dir/vvp/vvp}
fixture=$script_dir/bounded_queue_metadata_malformed.vvp
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/bounded-queue-metadata.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ ! -x "$vvp" ]; then
    echo "error: VVP runtime is not executable: $vvp" >&2
    exit 2
fi

set +e
"$vvp" "$fixture" > "$work_dir/stdout" 2> "$work_dir/stderr"
rc=$?
set -e

if [ "$rc" -ne 15 ]; then
    echo "FAIL bounded-queue metadata: expected rc=15, got rc=$rc" >&2
    cat "$work_dir/stdout" >&2
    cat "$work_dir/stderr" >&2
    exit 1
fi

sed "s|$fixture|bounded_queue_metadata_malformed.vvp|g" \
    < "$work_dir/stderr" | tr -d '\r' > "$work_dir/stderr-normalized"
sed "s|$fixture|bounded_queue_metadata_malformed.vvp|g" \
    < "$work_dir/stdout" | tr -d '\r' > "$work_dir/stdout-normalized"
if ! cmp -s "$script_dir/bounded_queue_metadata_malformed.stderr" \
        "$work_dir/stderr-normalized"; then
    echo "FAIL bounded-queue metadata: stderr mismatch" >&2
    diff -u "$script_dir/bounded_queue_metadata_malformed.stderr" \
        "$work_dir/stderr-normalized" >&2 || true
    exit 1
fi
if ! cmp -s "$script_dir/bounded_queue_metadata_malformed.stdout" \
        "$work_dir/stdout-normalized"; then
    echo "FAIL bounded-queue metadata: stdout mismatch" >&2
    diff -u "$script_dir/bounded_queue_metadata_malformed.stdout" \
        "$work_dir/stdout-normalized" >&2 || true
    exit 1
fi

echo "PASS malformed bounded-queue metadata rejection (15/15)"
