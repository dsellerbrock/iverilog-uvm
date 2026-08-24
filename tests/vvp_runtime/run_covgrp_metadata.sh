#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
vvp=${VVP:-$repo_dir/vvp/vvp}
boundary=tests/vvp_runtime/covgrp_metadata_boundary.vvp
malformed=tests/vvp_runtime/covgrp_metadata_malformed.vvp
sample_malformed=tests/vvp_runtime/covgrp_sample_malformed.vvp
options_malformed=tests/vvp_runtime/covgrp_options_malformed.vvp
expected=$script_dir/covgrp_metadata_malformed.stderr
sample_expected=$script_dir/covgrp_sample_malformed.stderr
options_expected=$script_dir/covgrp_options_malformed.stderr
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/covgrp-metadata.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ ! -x "$vvp" ]; then
    echo "error: VVP runtime is not executable: $vvp" >&2
    exit 2
fi

cd "$repo_dir"
"$vvp" "$boundary" > "$work_dir/boundary.stdout" \
    2> "$work_dir/boundary.stderr"
if [ -s "$work_dir/boundary.stdout" ] || \
   [ -s "$work_dir/boundary.stderr" ]; then
    echo "FAIL covergroup metadata: boundary fixture produced output" >&2
    exit 1
fi

"$vvp" "$malformed" > "$work_dir/malformed.stdout" \
    2> "$work_dir/malformed.stderr"
if [ -s "$work_dir/malformed.stdout" ]; then
    echo "FAIL covergroup metadata: expected empty malformed stdout" >&2
    exit 1
fi
tr -d '\r' < "$expected" > "$work_dir/expected-normalized"
tr -d '\r' < "$work_dir/malformed.stderr" > "$work_dir/stderr-normalized"
if ! cmp -s "$work_dir/expected-normalized" "$work_dir/stderr-normalized"; then
    echo "FAIL covergroup metadata: stderr mismatch" >&2
    diff -u "$work_dir/expected-normalized" \
        "$work_dir/stderr-normalized" >&2 || true
    exit 1
fi

"$vvp" "$sample_malformed" > "$work_dir/sample.stdout" \
    2> "$work_dir/sample.stderr"
if [ -s "$work_dir/sample.stdout" ]; then
    echo "FAIL covergroup metadata: expected empty sample stdout" >&2
    exit 1
fi
tr -d '\r' < "$sample_expected" > "$work_dir/sample-expected-normalized"
tr -d '\r' < "$work_dir/sample.stderr" > "$work_dir/sample-stderr-normalized"
if ! cmp -s "$work_dir/sample-expected-normalized" \
          "$work_dir/sample-stderr-normalized"; then
    echo "FAIL covergroup metadata: sample stderr mismatch" >&2
    diff -u "$work_dir/sample-expected-normalized" \
        "$work_dir/sample-stderr-normalized" >&2 || true
    exit 1
fi

"$vvp" "$options_malformed" > "$work_dir/options.stdout" \
    2> "$work_dir/options.stderr"
if [ -s "$work_dir/options.stdout" ]; then
    echo "FAIL covergroup metadata: expected empty options stdout" >&2
    exit 1
fi
tr -d '\r' < "$options_expected" > "$work_dir/options-expected-normalized"
tr -d '\r' < "$work_dir/options.stderr" > "$work_dir/options-stderr-normalized"
if ! cmp -s "$work_dir/options-expected-normalized" \
          "$work_dir/options-stderr-normalized"; then
    echo "FAIL covergroup metadata: options stderr mismatch" >&2
    diff -u "$work_dir/options-expected-normalized" \
        "$work_dir/options-stderr-normalized" >&2 || true
    exit 1
fi

echo "PASS covergroup transition/option metadata bounds (12/12)"
