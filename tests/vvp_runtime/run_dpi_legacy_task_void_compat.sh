#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
iverilog=${IVERILOG:-$repo_dir/local-install/bin/iverilog}
vvp=${VVP:-$repo_dir/vvp/vvp}
cc=${CC:-cc}
fixture=$script_dir/dpi_legacy_task_void_compat.vvp
c_file=$script_dir/dpi_legacy_task_void_compat.c
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dpi-legacy-task-void.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

if [ ! -x "$iverilog" ] || [ ! -x "$vvp" ]; then
    echo "error: compiler/runtime is not executable" >&2
    exit 2
fi
if ! command -v "$cc" >/dev/null 2>&1; then
    echo "error: C compiler not found: $cc" >&2
    exit 2
fi

case $(uname -s) in
  Darwin)
    library=$work_dir/dpi_legacy_task_void.dylib
    "$cc" -std=c11 -Wall -Wextra -Werror -dynamiclib \
        -o "$library" "$c_file"
    ;;
  *)
    library=$work_dir/dpi_legacy_task_void.so
    "$cc" -std=c11 -Wall -Wextra -Werror -shared -fPIC \
        -o "$library" "$c_file"
    ;;
esac

set +e
"$vvp" -d "$library" "$fixture" \
    > "$work_dir/stdout" 2> "$work_dir/stderr"
rc=$?
set -e

if [ "$rc" -ne 0 ] \
   || ! grep -F -x -q 'legacy void DPI task called' "$work_dir/stdout" \
   || ! grep -F -x -q 'PASS legacy DPI task void ABI compatibility' \
        "$work_dir/stdout" \
   || [ -s "$work_dir/stderr" ]; then
    echo "FAIL legacy DPI task void-ABI compatibility (rc=$rc)" >&2
    cat "$work_dir/stdout" >&2
    cat "$work_dir/stderr" >&2
    exit 1
fi

echo "PASS legacy DPI task void-ABI compatibility"

# A normal old image remains executable, but an old void-ABI task cannot
# acknowledge a disable. Compile the legal source with today's compiler, then
# change only its textual task opcode to the historical form. This keeps the
# generated export metadata/stub exact while exercising the old import ABI.
modern_image=$work_dir/dpi_legacy_disabled_modern.vvp
legacy_image=$work_dir/dpi_legacy_disabled.vvp
disabled_stub=${modern_image%.vvp}.dpiexport.c
disabled_source=$script_dir/dpi_legacy_task_disabled.sv
disabled_c=$script_dir/dpi_legacy_task_disabled.c

"$iverilog" -g2012 -s top -o "$modern_image" "$disabled_source"
if [ ! -f "$disabled_stub" ] \
   || ! grep -F -q '%dpi/call/task/ack "dpi_legacy_disabled_task|' \
        "$modern_image"; then
    echo "FAIL legacy disabled task: missing current task-ack image/stub" >&2
    exit 1
fi
sed 's#%dpi/call/task/ack#%dpi/call/task#' \
    "$modern_image" > "$legacy_image"
if grep -F -q '%dpi/call/task/ack' "$legacy_image" \
   || ! grep -F -q '%dpi/call/task "dpi_legacy_disabled_task|' \
        "$legacy_image"; then
    echo "FAIL legacy disabled task: opcode rewrite did not produce old ABI" >&2
    exit 1
fi

case $(uname -s) in
  Darwin)
    disabled_library=$work_dir/dpi_legacy_disabled.dylib
    "$cc" -std=c11 -Wall -Wextra -Werror -dynamiclib \
        -undefined dynamic_lookup -I "$repo_dir" -o "$disabled_library" \
        "$disabled_c" "$disabled_stub"
    ;;
  *)
    disabled_library=$work_dir/dpi_legacy_disabled.so
    "$cc" -std=c11 -Wall -Wextra -Werror -shared -fPIC \
        -I "$repo_dir" -o "$disabled_library" \
        "$disabled_c" "$disabled_stub"
    ;;
esac

set +e
"$vvp" -d "$disabled_library" "$legacy_image" \
    > "$work_dir/disabled-output" 2>&1
disabled_rc=$?
set -e

if [ "$disabled_rc" -eq 0 ] || [ "$disabled_rc" -ge 128 ] \
   || ! grep -F -q 'DPI fatal:' "$work_dir/disabled-output" \
   || ! grep -F -q \
        'legacy VVP void task ABI cannot acknowledge disable' \
        "$work_dir/disabled-output" \
   || grep -F -q 'UNEXPECTED:' "$work_dir/disabled-output"; then
    echo "FAIL legacy disabled task diagnostic (rc=$disabled_rc)" >&2
    cat "$work_dir/disabled-output" >&2
    exit 1
fi

echo "PASS legacy disabled DPI task fails loudly without an ack channel"
