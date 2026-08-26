#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
iverilog=${IVERILOG:-$repo_dir/local-install/bin/iverilog}
vvp=${VVP:-$repo_dir/local-install/bin/vvp}
ivpi=${IVPI:-$(dirname "$iverilog")/iverilog-vpi}
source_file=$repo_dir/tests/m10_dpi_narrow_return_abi_test.sv
c_file=$repo_dir/tests/m10_dpi_narrow_return_abi_test.c
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dpi-plain-char-abi.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ ! -x "$iverilog" ] || [ ! -x "$vvp" ] || [ ! -x "$ivpi" ]; then
    echo "error: missing executable compiler/runtime/VPI helper" >&2
    exit 2
fi

cc_bin=${CC:-$(command -v gcc || command -v clang || command -v cc)}
cflags=$($ivpi --cflags)
ldflags=$($ivpi --ldflags)
ldlibs=$($ivpi --ldlibs)
char_cflags=${DPI_CHAR_CFLAGS:-}

"$iverilog" -g2012 -o "$work_dir/plain-char.vvp" "$source_file"
# Intentional word splitting: iverilog-vpi reports its compile/link flags as
# shell words, and DPI_CHAR_CFLAGS adds the matching whole-toolchain char mode.
# shellcheck disable=SC2086
$cc_bin -c $cflags $char_cflags -o "$work_dir/plain-char.o" "$c_file"
# shellcheck disable=SC2086
$cc_bin -o "$work_dir/plain-char.vpi" $ldflags "$work_dir/plain-char.o" $ldlibs

set +e
"$vvp" -d "$work_dir/plain-char.vpi" "$work_dir/plain-char.vvp" \
    > "$work_dir/stdout" 2> "$work_dir/stderr"
rc=$?
set -e

if [ "$rc" -ne 0 ] \
   || ! grep -F -x -q 'PASS m10_dpi_narrow_return_abi_test' "$work_dir/stdout" \
   || grep -F -q 'FAIL ' "$work_dir/stdout"; then
    echo "FAIL plain-char DPI ABI (rc=$rc flags=${char_cflags:-default})" >&2
    cat "$work_dir/stdout" >&2
    cat "$work_dir/stderr" >&2
    exit 1
fi

echo "PASS plain-char DPI ABI (flags=${char_cflags:-default})"
