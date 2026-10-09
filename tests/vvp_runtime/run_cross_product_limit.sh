#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
iverilog=${IVERILOG:-$repo_dir/local-install/bin/iverilog}
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/cross-product-limit.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

for standard in 2017 2023; do
  at_limit=$work_dir/at-limit-$standard.vvp
  at_output=$work_dir/at-limit-$standard.log
  if ! "$iverilog" -g"$standard" -o "$at_limit" \
      "$repo_dir/tests/m11_cross_product_at_limit.sv" \
      >"$at_output" 2>&1; then
    cat "$at_output"
    echo "FAIL cross with 65,536 bins under -g$standard" >&2
    exit 1
  fi
  if grep -q "cross 'cx'.*limit" "$at_output"; then
    cat "$at_output"
    echo "FAIL cross at the supported limit was refused under -g$standard" >&2
    exit 1
  fi

  over_limit=$work_dir/over-limit-$standard.vvp
  over_output=$work_dir/over-limit-$standard.log
  set +e
  "$iverilog" -g"$standard" -o "$over_limit" \
    "$repo_dir/tests/m11_cross_product_over_limit.sv" \
    >"$over_output" 2>&1
  rc=$?
  set -e
  if [ "$rc" -eq 0 ] \
     || ! grep -Fq "error: cross 'cx' requires more than 65536 automatic bins" \
          "$over_output"; then
    cat "$over_output"
    echo "FAIL cross above 65,536 bins was not refused under -g$standard" >&2
    exit 1
  fi
  echo "PASS cross product limit (-g$standard)"
done
