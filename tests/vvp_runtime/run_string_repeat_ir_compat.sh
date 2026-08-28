#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
iverilog=${IVERILOG:-}
vvp=${VVP:-$repo_dir/vvp/vvp}
legacy_fixture=$script_dir/string_repeat_legacy.vvp
legacy_expected=$script_dir/string_repeat_legacy.stdout
typed_source=$script_dir/string_repeat_typed.sv
typed_expected=$script_dir/string_repeat_typed.stdout
module_dir=${VPI_MODULE_DIR:-}
if [ -z "$iverilog" ]; then
    for candidate in "$repo_dir/driver/iverilog" \
                     "$repo_dir/local-install/bin/iverilog" \
                     "$(command -v iverilog 2>/dev/null || true)"; do
        if [ -n "$candidate" ] && [ -x "$candidate" ]; then
            iverilog=$candidate
            break
        fi
    done
fi
if [ -z "$module_dir" ]; then
    for candidate in "$repo_dir/vpi" "$repo_dir/local-install/lib/ivl" \
                     "$(dirname "$(command -v "$vvp")")/../lib/ivl"; do
        if [ -f "$candidate/system.vpi" ]; then
            module_dir=$candidate
            break
        fi
    done
fi
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/string-repeat-ir.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ ! -x "$iverilog" ] || [ ! -x "$vvp" ]; then
    echo "error: Icarus compiler/runtime is not executable" >&2
    exit 2
fi
if [ -z "$module_dir" ] || [ ! -f "$module_dir/system.vpi" ]; then
    echo "error: cannot locate system.vpi for $vvp" >&2
    exit 2
fi

"$vvp" -M "$module_dir" -m system "$legacy_fixture" \
    > "$work_dir/legacy.stdout" 2> "$work_dir/legacy.stderr"
if [ -s "$work_dir/legacy.stderr" ]; then
    echo "FAIL legacy string-repeat bytecode: expected empty stderr" >&2
    cat "$work_dir/legacy.stderr" >&2
    exit 1
fi
tr -d '\r' < "$legacy_expected" > "$work_dir/legacy.expected"
tr -d '\r' < "$work_dir/legacy.stdout" > "$work_dir/legacy.normalized"
if ! cmp -s "$work_dir/legacy.expected" "$work_dir/legacy.normalized"; then
    echo "FAIL legacy string-repeat bytecode: stdout mismatch" >&2
    diff -u "$work_dir/legacy.expected" "$work_dir/legacy.normalized" >&2 || true
    exit 1
fi

"$iverilog" -g2012 -o "$work_dir/typed.vvp" "$typed_source"
if [ "$(grep -F -c '%rep/str/s ' "$work_dir/typed.vvp")" -ne 1 ] \
   || [ "$(grep -F -c '%rep/str/u ' "$work_dir/typed.vvp")" -ne 2 ] \
   || grep -F -q '    %rep/str ' "$work_dir/typed.vvp"; then
    echo "FAIL typed string-repeat bytecode: opcode signedness mismatch" >&2
    grep -F '%rep/str' "$work_dir/typed.vvp" >&2 || true
    exit 1
fi
"$vvp" "$work_dir/typed.vvp" \
    > "$work_dir/typed.stdout" 2> "$work_dir/typed.stderr"
if [ -s "$work_dir/typed.stderr" ]; then
    echo "FAIL typed string-repeat bytecode: expected empty stderr" >&2
    cat "$work_dir/typed.stderr" >&2
    exit 1
fi
tr -d '\r' < "$typed_expected" > "$work_dir/typed.expected"
tr -d '\r' < "$work_dir/typed.stdout" > "$work_dir/typed.normalized"
if ! cmp -s "$work_dir/typed.expected" "$work_dir/typed.normalized"; then
    echo "FAIL typed string-repeat bytecode: stdout mismatch" >&2
    diff -u "$work_dir/typed.expected" "$work_dir/typed.normalized" >&2 || true
    exit 1
fi

echo "PASS string-repeat VVP compatibility and typed opcodes (6/6)"
