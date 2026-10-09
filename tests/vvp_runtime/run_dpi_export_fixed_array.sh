#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
iverilog=${IVERILOG:-$repo_dir/local-install/bin/iverilog}
vvp=${VVP:-$repo_dir/vvp/vvp}
cc=${CC:-cc}
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dpi-export-fixed-array.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

source_file=$repo_dir/tests/m10_dpi_export_fixed_array_test.sv
c_file=$repo_dir/tests/m10_dpi_export_fixed_array_test.c

for standard in 2017 2023; do
  image=$work_dir/export-fixed-array-$standard.vvp
  stub=${image%.vvp}.dpiexport.c
  "$iverilog" -g"$standard" -o "$image" "$source_file"

  case $(uname -s) in
    Darwin)
      library=$work_dir/export-fixed-array-$standard.dylib
      "$cc" -std=c11 -Wall -Wextra -Werror -dynamiclib \
        -undefined dynamic_lookup -I "$repo_dir" -o "$library" \
        "$c_file" "$stub"
      ;;
    *)
      library=$work_dir/export-fixed-array-$standard.so
      "$cc" -std=c11 -Wall -Wextra -Werror -shared -fPIC \
        -I "$repo_dir" -o "$library" "$c_file" "$stub"
      ;;
  esac

  output=$work_dir/output-$standard
  "$vvp" -d "$library" "$image" > "$output" 2>&1
  if ! grep -q '^PASS m10_dpi_export_fixed_array_test$' "$output"; then
    cat "$output"
    echo "FAIL DPI export fixed-array reducer under -g$standard" >&2
    exit 1
  fi
  cat "$output"
done
