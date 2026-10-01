#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
iverilog=${IVERILOG:-$repo_dir/local-install/bin/iverilog}
vvp=${VVP:-$repo_dir/local-install/bin/vvp}
ivpi=${IVPI:-$(dirname "$iverilog")/iverilog-vpi}
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/svdpi-bitsel.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

cc_bin=${CC:-$(command -v cc)}
cflags=$($ivpi --cflags)
ldflags=$($ivpi --ldflags)
ldlibs=$($ivpi --ldlibs)
# iverilog-vpi emits shell words for the compiler and linker.
# shellcheck disable=SC2086
$cc_bin -std=c11 -Wall -Wextra -Werror $cflags -I "$repo_dir" -c "$repo_dir/tests/svdpi_bitsel_selfcheck.c" -o "$work_dir/bitsel.o"
# shellcheck disable=SC2086
$cc_bin $ldflags -o "$work_dir/bitsel.vpi" "$work_dir/bitsel.o" $ldlibs
for edition in 2017 2023; do
    "$iverilog" -g"$edition" -s svdpi_bitsel_selfcheck -o "$work_dir/bitsel.vvp" "$repo_dir/tests/svdpi_bitsel_selfcheck.sv"
    "$vvp" -n -d "$work_dir/bitsel.vpi" "$work_dir/bitsel.vvp"
done
