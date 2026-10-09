#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
iverilog=${IVERILOG:-$repo_dir/local-install/bin/iverilog}
vvp=${VVP:-$repo_dir/local-install/bin/vvp}
ivpi=${IVPI:-$(dirname "$iverilog")/iverilog-vpi}
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/vpi-source-location.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

cc_bin=${CC:-$(command -v cc)}
cflags=$($ivpi --cflags)
ldflags=$($ivpi --ldflags)
ldlibs=$($ivpi --ldlibs)
# shellcheck disable=SC2086
$cc_bin -std=c11 -Wall -Wextra -Werror $cflags -c \
  "$script_dir/vpi_source_location_test.c" -o "$work_dir/source.o"
# shellcheck disable=SC2086
$cc_bin $ldflags -o "$work_dir/source.vpi" "$work_dir/source.o" $ldlibs

for standard in 2017 2023; do
  image=$work_dir/source-$standard.vvp
  output=$work_dir/source-$standard.log
  "$iverilog" -g"$standard" -o "$image" \
    "$script_dir/vpi_source_location_test.sv"
  if ! "$vvp" -n -M "$work_dir" -m source "$image" >"$output" 2>&1; then
    cat "$output"
    echo "FAIL VPI source locations (-g$standard)" >&2
    exit 1
  fi
  grep -Fq "PASS VPI source locations" "$output" || {
    cat "$output"
    echo "FAIL missing source location success marker (-g$standard)" >&2
    exit 1
  }
  echo "PASS VPI source locations (-g$standard)"
done
