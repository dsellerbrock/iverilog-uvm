#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
iverilog=${IVERILOG:-$repo_dir/local-install/bin/iverilog}
source_file=$repo_dir/tests/m10_dpi_narrow_return_abi_test.sv
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dpi-narrow-metadata.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ ! -x "$iverilog" ]; then
    echo "error: iverilog compiler is not executable: $iverilog" >&2
    exit 2
fi

"$iverilog" -g2012 -o "$work_dir/narrow.vvp" "$source_file"

check_call()
{
    expected=$1
    if ! grep -F -q "$expected" "$work_dir/narrow.vvp"; then
        echo "FAIL narrow DPI return metadata: missing $expected" >&2
        grep -F '%dpi/call' "$work_dir/narrow.vvp" >&2 || true
        exit 1
    fi
}

# These prefixes select the exact Annex-H C return type in libffi. A runtime
# value-only test cannot distinguish the correct narrow CIF from a historical
# sint32 call whose low bits happen to match.
check_call '%dpi/call/vec4 "c_dpi_return_sbyte|^bpW", 2, 8;'
check_call '%dpi/call/vec4 "c_dpi_return_ubyte|^BpV", 2, 8;'
check_call '%dpi/call/vec4 "c_dpi_plain_char_roundtrip|^bb+b", 2, 8;'
check_call '%dpi/call/vec4 "c_dpi_return_sshort|^hi", 1, 16;'
check_call '%dpi/call/vec4 "c_dpi_return_ushort|^Hi", 1, 16;'
check_call '%dpi/call/vec4 "c_dpi_return_bit|^Bi", 1, 1;'
check_call '%dpi/call/vec4 "c_dpi_return_logic|^gi", 1, 1;'
check_call '%dpi/call/vec4 "c_dpi_return_byte_enum|^b", 0, 8;'
check_call '%dpi/call/vec4 "c_dpi_return_uint_enum|^I", 0, 32;'

echo "PASS exact narrow DPI return metadata (9/9)"
