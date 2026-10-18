#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
iverilog=${IVERILOG:-iverilog}
vvp=${VVP:-vvp}
run_with_timeout=$repo_dir/scripts/run_with_timeout.py
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/covergroup-extension-cross.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if ! python3 "$run_with_timeout" 60 -- "$iverilog" -g2023 -s test -o "$work_dir/positive.vvp" \
    "$script_dir/covergroup_extension_implicit_cross.sv" \
    >"$work_dir/positive.compile" 2>&1; then
    cat "$work_dir/positive.compile" >&2
    exit 1
fi
if ! python3 "$run_with_timeout" 60 -- "$vvp" -n "$work_dir/positive.vvp" >"$work_dir/positive.run" 2>&1; then
    cat "$work_dir/positive.run" >&2
    exit 1
fi
if ! grep -Fxq 'PASS implicit cross: base=80.000 flat=80.000 direct=80.000 flat-direct=80.000' \
    "$work_dir/positive.run"; then
    cat "$work_dir/positive.run" >&2
    exit 1
fi
cat "$work_dir/positive.run"

if python3 "$run_with_timeout" 60 -- "$iverilog" -g2023 -s test -o "$work_dir/negative.vvp" \
    "$script_dir/covergroup_extension_implicit_cross_index.sv" \
    >"$work_dir/negative.compile" 2>&1; then
    echo 'FAIL: unsupported indexed cross compiled' >&2
    exit 1
fi
if ! grep -Fq "sorry: covergroup 'cg' extension coverpoint '__implicit_cross_0': an expression that depends on an inherited sample argument or cannot be serialized is not supported when sampled through a base-class handle (IEEE 1800-2023 19.4.1)." \
    "$work_dir/negative.compile"; then
    cat "$work_dir/negative.compile" >&2
    exit 1
fi
if ! grep -Fq '1 error(s) during elaboration.' "$work_dir/negative.compile"; then
    cat "$work_dir/negative.compile" >&2
    exit 1
fi
echo 'PASS unsupported indexed cross rejected during elaboration'

if python3 "$run_with_timeout" 60 -- "$iverilog" -g2017 -s test -o "$work_dir/edition.vvp" \
    "$script_dir/covergroup_extension_implicit_cross_index.sv" \
    >"$work_dir/edition.compile" 2>&1; then
    echo 'FAIL: 2017 accepted embedded covergroup inheritance' >&2
    exit 1
fi
if ! grep -Fq 'embedded covergroup inheritance requires IEEE1800-2023' \
    "$work_dir/edition.compile"; then
    cat "$work_dir/edition.compile" >&2
    exit 1
fi
if grep -Fq 'sorry:' "$work_dir/edition.compile"; then
    cat "$work_dir/edition.compile" >&2
    exit 1
fi
echo 'PASS 2017 extension edition diagnostic'
