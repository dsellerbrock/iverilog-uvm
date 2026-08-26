#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
iverilog=${IVERILOG:-$repo_dir/local-install/bin/iverilog}
vvp=${VVP:-$repo_dir/local-install/bin/vvp}
ivpi=${IVPI:-$(dirname "$iverilog")/iverilog-vpi}
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dpi-prefixless-vec4.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ ! -x "$iverilog" ] || [ ! -x "$vvp" ] || [ ! -x "$ivpi" ]; then
    echo "error: missing executable compiler/runtime/VPI helper" >&2
    exit 2
fi

source_file=$script_dir/dpi_prefixless_vec4_compat.sv
c_file=$script_dir/dpi_prefixless_vec4_compat.c
new_image=$work_dir/new.vvp
old_image=$work_dir/prefixless.vvp

"$iverilog" -g2012 -o "$new_image" "$source_file"

# Current images prefix an integral signature with the exact Annex H return
# ABI. Images emitted before that metadata existed began immediately with the
# argument signature. Rewrite only this known int-return call to the old form,
# then require the current runtime to load and execute it.
sed 's/dpi_prefixless_add|\^ii/dpi_prefixless_add|i/' \
    "$new_image" > "$old_image"
if ! grep -F -q '%dpi/call/vec4 "dpi_prefixless_add|i", 1, 32;' \
        "$old_image" \
   || grep -F -q 'dpi_prefixless_add|^' "$old_image"; then
    echo "FAIL: could not construct the prefixless compatibility image" >&2
    grep -F 'dpi_prefixless_add|' "$old_image" >&2 || true
    exit 1
fi

cc_bin=${CC:-$(command -v gcc || command -v clang || command -v cc)}
cflags=$($ivpi --cflags)
ldflags=$($ivpi --ldflags)
ldlibs=$($ivpi --ldlibs)
# Intentional word splitting: iverilog-vpi reports compile/link flags as
# shell words.
# shellcheck disable=SC2086
$cc_bin -c $cflags -o "$work_dir/compat.o" "$c_file"
# shellcheck disable=SC2086
$cc_bin -o "$work_dir/compat.vpi" $ldflags "$work_dir/compat.o" $ldlibs

set +e
"$vvp" -d "$work_dir/compat.vpi" "$old_image" \
    > "$work_dir/stdout" 2> "$work_dir/stderr"
rc=$?
set -e

if [ "$rc" -ne 0 ] \
   || ! grep -F -x -q 'PASS prefixless DPI vec4 call compatibility' \
        "$work_dir/stdout" \
   || [ -s "$work_dir/stderr" ]; then
    echo "FAIL prefixless DPI vec4 call compatibility (rc=$rc)" >&2
    cat "$work_dir/stdout" >&2
    cat "$work_dir/stderr" >&2
    exit 1
fi

echo "PASS prefixless DPI vec4 call compatibility"
