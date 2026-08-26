#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
iverilog=${IVERILOG:-$repo_dir/local-install/bin/iverilog}
vvp=${VVP:-$repo_dir/vvp/vvp}
cc=${CC:-cc}
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dpi-export-output-logic.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

image=$work_dir/output_logic.vvp
stub=${image%.vvp}.dpiexport.c
source_file=$repo_dir/tests/m10_dpi_export_output_logic_default_test.sv
c_file=$repo_dir/tests/m10_dpi_export_output_logic_default_test.c

"$iverilog" -g2012 -o "$image" "$source_file"

case $(uname -s) in
  Darwin)
    library=$work_dir/output_logic.dylib
    "$cc" -std=c11 -Wall -Wextra -Werror -dynamiclib \
      -undefined dynamic_lookup -I "$repo_dir" -o "$library" \
      "$c_file" "$stub"
    ;;
  *)
    library=$work_dir/output_logic.so
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
   || ! grep -q '^  scalar output defaults: untouched=3 observed=3 result=3$' \
        "$work_dir/output" \
   || ! grep -q '^PASS m10_dpi_export_output_logic_default_test$' \
        "$work_dir/output"; then
    echo "FAIL DPI export scalar output logic default-X reducer" >&2
    exit 1
fi

echo "PASS DPI export scalar output logic default-X reducer"
