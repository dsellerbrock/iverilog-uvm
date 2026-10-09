#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
iverilog=${IVERILOG:-$repo_dir/local-install/bin/iverilog}
vvp=${VVP:-$repo_dir/local-install/bin/vvp}
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/merged-transition-cardinality.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

for standard in 2017 2023; do
  image=$work_dir/merged-transition-$standard.vvp
  output=$work_dir/merged-transition-$standard.log
  "$iverilog" -g"$standard" -o "$image" \
    "$repo_dir/tests/m11_merged_transition_cardinality_test.sv"
  "$vvp" "$image" >"$output" 2>&1 || {
    cat "$output"
    echo "FAIL merged transition cardinality (-g$standard)" >&2
    exit 1
  }
  grep -Fq PASSED "$output" || {
    cat "$output"
    echo "FAIL missing success marker (-g$standard)" >&2
    exit 1
  }
  echo "PASS merged transition cardinality (-g$standard)"
done
