#!/bin/sh

set -eu

iverilog_cmd=${IVERILOG:-iverilog}
test_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/ivl-xnf-identifiers.XXXXXX")

cleanup()
{
    rm -f "$temp_dir/escaped.xnf" "$temp_dir/long.xnf"
    rmdir "$temp_dir"
}
trap cleanup EXIT HUP INT TERM

"$iverilog_cmd" -g2012 -tfpga -parch=generic-xnf \
    -o "$temp_dir/escaped.xnf" "$test_dir/xnf_escaped_identifiers.v"

# The encoding is injective: an unsafe comma name and an ordinary name that
# resembles its encoded form must remain distinct. No user identifier may add
# a comma-separated field to a SIG, SYM, or PIN record.
grep -F 'PIN=__ivl_xnf_612C62' "$temp_dir/escaped.xnf" >/dev/null
grep -F 'PIN=__ivl_xnf_5F5F69766C5F786E665F363132433632' \
    "$temp_dir/escaped.xnf" >/dev/null
if grep -F 'FIELD=BAD' "$temp_dir/escaped.xnf" >/dev/null; then
    echo 'escaped XNF identifier was emitted without encoding' >&2
    exit 1
fi
awk -F, '
    /^SIG,/ && NF != 3 { bad = 1 }
    /^SYM,/ && NF != 4 { bad = 1 }
    /^    PIN,/ && NF != 4 && NF != 6 { bad = 1 }
    END { exit bad }
' "$temp_dir/escaped.xnf"

"$iverilog_cmd" -g2012 -tfpga -parch=generic-xnf \
    -o "$temp_dir/long.xnf" "$test_dir/xnf_long_identifier.v"

# This hierarchy exceeds the backend's former 1024-byte stack buffer. Ensure
# the complete instance record survives instead of aborting or truncating.
awk '
    /^SYM,/ && length($0) > 1200 { found += 1 }
    END { exit found < 2 }
' "$temp_dir/long.xnf"

echo PASSED
