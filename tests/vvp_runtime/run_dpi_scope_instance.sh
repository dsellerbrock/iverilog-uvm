#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$script_dir/../.." && pwd)
iverilog=${IVERILOG:-$repo_dir/local-install/bin/iverilog}
vvp=${VVP:-$repo_dir/vvp/vvp}
cc=${CC:-cc}
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/dpi-scope-instance.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

case $(uname -s) in
  Darwin)
    library=$work_dir/scope.dylib
    "$cc" -std=c11 -Wall -Wextra -Werror -dynamiclib \
      -undefined dynamic_lookup -I "$repo_dir" -o "$library" \
      "$repo_dir/tests/m10m_dpi_scope_instance_test.c"
    ;;
  *)
    library=$work_dir/scope.so
    "$cc" -std=c11 -Wall -Wextra -Werror -shared -fPIC \
      -I "$repo_dir" -o "$library" \
      "$repo_dir/tests/m10m_dpi_scope_instance_test.c"
    ;;
esac

for edition in 2017 2023; do
  image=$work_dir/scope_$edition.vvp
  if ! "$iverilog" -g"$edition" -gno-icarus-misc -gno-xtypes \
       -s m10m_dpi_scope_instance_test -o "$image" \
       "$repo_dir/tests/m10m_dpi_scope_instance_test.sv" \
       > "$work_dir/compile.log" 2>&1; then
    cat "$work_dir/compile.log" >&2
    exit 1
  fi
  if [ -s "$work_dir/compile.log" ]; then
    cat "$work_dir/compile.log" >&2
    exit 1
  fi
  if ! "$vvp" -n -d "$library" "$image" > "$work_dir/output" 2>&1; then
    cat "$work_dir/output" >&2
    exit 1
  fi
  if ! grep -F -x -q 'PASS m10m_dpi_scope_instance_test' \
       "$work_dir/output"; then
    cat "$work_dir/output" >&2
    exit 1
  fi
  for id in 0 1; do
    if ! grep -F -x -q "PASS m10m_scope_model $id" "$work_dir/output"; then
      cat "$work_dir/output" >&2
      exit 1
    fi
  done
done

echo 'PASS DPI context instance scope (2017/2023)'
