#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
iverilog=${IVERILOG:-$repo_dir/local-install/bin/iverilog}
vvp=${VVP:-$repo_dir/vvp/vvp}
cc=${CC:-cc}
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dpi-disable-protocol.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

image=$work_dir/dpi_disable_protocol.vvp
stub=${image%.vvp}.dpiexport.c
source_file=$repo_dir/tests/m10l_dpi_disable_protocol_test.sv
c_file=$repo_dir/tests/m10l_dpi_disable_protocol_test.c

fail()
{
    echo "FAIL DPI disable protocol: $*" >&2
    exit 1
}

"$iverilog" -g2012 -s m10l_dpi_disable_protocol_test \
  -o "$image" "$source_file"

[ -f "$stub" ] || fail "compiler did not generate $stub"

# Annex H.8.2 requires each exported task to be a C int-returning function.
# Assert the generated source, not merely the hand-written extern declarations:
# incompatible void definitions can otherwise hide in a separate translation
# unit and only appear to work on permissive ABIs.
for task_name in sv_normal_task sv_direct_task sv_ancestor_task \
                 sv_reentry_delay_task; do
    if ! grep -Eq "^int[[:space:]]+${task_name}\\(void\\)[[:space:]]*$" "$stub"; then
        fail "generated stub for $task_name is not 'int $task_name(void)'"
    fi
    if grep -Eq "^void[[:space:]]+${task_name}\\(" "$stub"; then
        fail "generated stub for $task_name still has the legacy void ABI"
    fi
    if ! grep -Fq "__ivl_dpi_export_call_i(\"$task_name\"" "$stub"; then
        fail "generated stub for $task_name does not collect task status"
    fi
done
if ! grep -Eq '^int[[:space:]]+sv_concurrent_task\(int a0\)$' "$stub" \
   || ! grep -Fq '__ivl_dpi_export_call_i("sv_concurrent_task"' "$stub"; then
    fail "generated stub for sv_concurrent_task does not use the int task ABI"
fi
if ! grep -Eq '^int[[:space:]]+sv_reentry_disable_caller\(void\)$' "$stub" \
   || ! grep -Fq '__ivl_dpi_export_call_i("sv_reentry_disable_caller"' "$stub"; then
    fail "re-entry disable witness is not a synchronous integer export"
fi
if ! grep -Eq '^int[[:space:]]+sv_vpi_context_delay_task\(int a0\)$' "$stub" \
   || ! grep -Fq '__ivl_dpi_export_call_i("sv_vpi_context_delay_task"' "$stub"; then
    fail "resumed-VPI witness task does not use the int task ABI"
fi

# Newly compiled imported tasks must use the checked int-return ABI. Keep the
# old %dpi/call/task opcode available only for loading old void-ABI images.
ack_count=$(grep -c '%dpi/call/task/ack' "$image" || true)
[ "$ack_count" -eq 6 ] \
  || fail "image has $ack_count checked imported-task calls, expected 6"
for import_name in c_normal c_direct c_ancestor c_concurrent \
                   c_resumed_reentry c_resumed_vpi_context; do
    if ! grep -Eq "%dpi/call/task/ack[[:space:]]+\"${import_name}\\|" "$image"; then
        fail "$import_name was not emitted as %dpi/call/task/ack"
    fi
    if grep -Eq "%dpi/call/task[[:space:]]+\"${import_name}\\|" "$image"; then
        fail "$import_name was emitted with the legacy unchecked opcode"
    fi
done

case $(uname -s) in
  Darwin)
    library=$work_dir/dpi_disable_protocol.dylib
    "$cc" -std=c11 -Wall -Wextra -Werror -dynamiclib \
      -undefined dynamic_lookup -I "$repo_dir" -o "$library" \
      "$c_file" "$stub"
    ;;
  *)
    library=$work_dir/dpi_disable_protocol.so
    "$cc" -std=c11 -Wall -Wextra -Werror -shared -fPIC \
      -I "$repo_dir" -o "$library" "$c_file" "$stub"
    ;;
esac

set +e
"$vvp" -d "$library" "$image" > "$work_dir/output" 2>&1
rc=$?
set -e
cat "$work_dir/output"

if [ "$rc" -ne 0 ] \
   || grep -q '^FAIL' "$work_dir/output" \
   || ! grep -q '^PASS m10l_dpi_disable_protocol_test$' "$work_dir/output"; then
    fail "simulation did not complete all positive disable/acknowledgment paths"
fi

echo "PASS DPI disable protocol"
