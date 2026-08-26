#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
iverilog=${IVERILOG:-$repo_dir/local-install/bin/iverilog}
vvp=${VVP:-$repo_dir/vvp/vvp}
cc=${CC:-cc}
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dpi-disable-negative.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ ! -x "$iverilog" ] || [ ! -x "$vvp" ]; then
    echo "error: missing executable compiler/runtime" >&2
    exit 2
fi
if ! command -v "$cc" >/dev/null 2>&1; then
    echo "error: C compiler not found: $cc" >&2
    exit 2
fi

build_library()
{
    case_name=$1
    case_dir=$2
    image=$case_dir/$case_name.vvp
    c_file=$script_dir/$case_name.c
    stub=${image%.vvp}.dpiexport.c

    "$iverilog" -g2012 -o "$image" "$script_dir/$case_name.sv"

    case $case_name in
      dpi_disable_task_bad_zero)
        if ! grep -F -q \
            '%dpi/call/task/ack "dpi_bad_disabled_task|' "$image"; then
            echo "FAIL $case_name: compiler did not emit the task-ack opcode" >&2
            exit 1
        fi
        ;;
      dpi_disable_task_bad_one)
        if ! grep -F -q \
            '%dpi/call/task/ack "dpi_bad_normal_task|' "$image"; then
            echo "FAIL $case_name: compiler did not emit the task-ack opcode" >&2
            exit 1
        fi
        ;;
    esac

    set -- "$c_file"
    if [ -f "$stub" ]; then
        set -- "$@" "$stub"
    fi

    case $(uname -s) in
      Darwin)
        built_library=$case_dir/$case_name.dylib
        "$cc" -std=c11 -Wall -Wextra -Werror -dynamiclib \
            -undefined dynamic_lookup -I "$repo_dir" -o "$built_library" "$@"
        ;;
      *)
        built_library=$case_dir/$case_name.so
        "$cc" -std=c11 -Wall -Wextra -Werror -shared -fPIC \
            -I "$repo_dir" -o "$built_library" "$@"
        ;;
    esac
}

expect_protocol_fatal()
{
    case_name=$1
    import_name=$2
    reason=$3
    extra=${4:-}
    case_dir=$work_dir/$case_name
    mkdir -p "$case_dir"
    image=$case_dir/$case_name.vvp
    output=$case_dir/output
    build_library "$case_name" "$case_dir"
    library=$built_library

    set +e
    "$vvp" -d "$library" "$image" > "$output" 2>&1
    rc=$?
    set -e

    if [ "$rc" -eq 0 ]; then
        echo "FAIL $case_name: expected a fatal simulation error" >&2
        cat "$output" >&2
        exit 1
    fi
    if [ "$rc" -ge 128 ]; then
        echo "FAIL $case_name: runtime crashed with exit $rc" >&2
        cat "$output" >&2
        exit 1
    fi
    if ! grep -F -q 'DPI fatal:' "$output" \
       || ! grep -F -q "'$import_name'" "$output" \
       || ! grep -F -q "$reason" "$output"; then
        echo "FAIL $case_name: missing expected DPI protocol diagnostic" >&2
        echo "  import: $import_name" >&2
        echo "  reason: $reason" >&2
        cat "$output" >&2
        exit 1
    fi
    if [ -n "$extra" ] && ! grep -F -q "$extra" "$output"; then
        echo "FAIL $case_name: diagnostic missing: $extra" >&2
        cat "$output" >&2
        exit 1
    fi
    if grep -F -q 'UNEXPECTED:' "$output"; then
        echo "FAIL $case_name: execution continued through the protocol fatal" >&2
        cat "$output" >&2
        exit 1
    fi

    echo "PASS $case_name (expected fatal)"
}

expect_protocol_fatal \
    dpi_disable_task_bad_zero \
    dpi_bad_disabled_task \
    'returned disable status 0, expected 1'

expect_protocol_fatal \
    dpi_disable_task_bad_one \
    dpi_bad_normal_task \
    'returned disable status 1, expected 0'

expect_protocol_fatal \
    dpi_disable_function_missing_ack \
    dpi_bad_unacked_function \
    'returned without calling svAckDisabledState()'

expect_protocol_fatal \
    dpi_disable_export_after_state \
    dpi_bad_export_after_disable \
    'called after imported DPI subroutine' \
    "'dpi_forbidden_export'"

echo "PASS DPI disable-protocol expected-fatals (4/4)"
