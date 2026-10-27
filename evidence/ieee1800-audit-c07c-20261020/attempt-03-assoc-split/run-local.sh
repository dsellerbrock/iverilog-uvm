#!/usr/bin/env bash
set -u
REPO="$1"
EVIDENCE="$2"
LOCALRUN=/Users/danielellerbrock/codex-supervisor/localrun
REV=cc25756d187314742d347267c2a513b3e640a7fb
if [ "${3:-}" = resume ]; then
  TMP_ROOT="$4"
else
  TMP_ROOT=$(mktemp -d /tmp/a3-c07-assoc-cc257.XXXXXX)
fi
SRC="$TMP_ROOT/source"
PREFIX="$TMP_ROOT/install"
OUT="$EVIDENCE/local-results"
export PATH="/opt/homebrew/opt/bison/bin:$PATH"
export PKG_CONFIG_PATH="/opt/homebrew/opt/libffi/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export CPPFLAGS="-I/opt/homebrew/opt/libffi/include${CPPFLAGS:+ $CPPFLAGS}"
export LDFLAGS="-L/opt/homebrew/opt/libffi/lib${LDFLAGS:+ $LDFLAGS}"
mkdir -p "$OUT"
printf 'host=%s\n' "$(uname -a)"
printf 'date_utc=%s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'source_revision=%s\n' "$REV"
printf 'bison_version=%s\n' "$(bison --version | head -n 1)"
if [ "${3:-}" != resume ]; then
  mkdir -p "$SRC"
  git -C "$REPO" archive "$REV" | tar -x -C "$SRC"
  cp "$REPO"/tests/1800_audit/c07/a{1,2,3,4,5,6}_*.sv "$SRC/"
fi
sha256sum "$SRC"/a*.sv
if [ "${3:-}" = resume ]; then
  make -C "$SRC/vvp" -j3 CPPFLAGS='-I. -I.. -I/opt/homebrew/opt/libffi/include -I/opt/homebrew/opt/z3/include -DHAVE_CONFIG_H -DICARUS_VPI_CONST=const -DUSE_LIBFFI=1' LDFLAGS='-Wl,-all_load -L/opt/homebrew/opt/libffi/lib -L/opt/homebrew/opt/z3/lib' && make -C "$SRC" -j3 install
else
  (cd "$SRC" && autoconf && ./configure --prefix="$PREFIX" && make -j3 && make install)
fi >"$EVIDENCE/build.log" 2>&1
build_rc=$?
printf 'build_rc=%s\n' "$build_rc"
if [ "$build_rc" -ne 0 ]; then
  cat "$EVIDENCE/build.log"
  exit "$build_rc"
fi
TOOL="$PREFIX/bin"
printf 'tool_version='; "$TOOL/iverilog" -V | head -n 1
shasum -a 256 "$TOOL/iverilog" "$TOOL/vvp"

bounded() {
  label="$1" stdout="$2" stderr="$3" timing="$4"
  shift 4
  if "$LOCALRUN" 30 /bin/bash -c 'out="$1"; err="$2"; shift 2; exec "$@" >"$out" 2>"$err"' _ "$stdout" "$stderr" "$@" >"$timing" 2>&1; then
    COMMAND_RC=0
  else
    COMMAND_RC=$?
  fi
  printf '%s rc=%s\n' "$label" "$COMMAND_RC" >>"$EVIDENCE/run-summary.txt"
  return "$COMMAND_RC"
}

for edition in 2017 2023; do
  for item in 'a1_class_assoc_keys a1_class_assoc_keys' 'a2_derived_assoc_key a2_derived_assoc_key' 'a3_null_assoc_key a3_null_assoc_key' 'a4_struct_assoc_key a4_struct_assoc_key' 'a5_assoc_array_assignment a5_assoc_array_assignment' 'a6_assoc_array_args a6_assoc_array_args'; do
    set -- $item
    name="$1" top="$2"
    binary="$OUT/${name}-${edition}.vvp"
    compile_label="${edition}-${name}-compile"
    bounded "$compile_label" "$OUT/${compile_label}.out" "$OUT/${compile_label}.err" "$OUT/${compile_label}.localrun.txt" "$TOOL/iverilog" "-g$edition" -s "$top" -o "$binary" "$SRC/$name.sv"
    compile_rc=$?
    if [ "$compile_rc" -eq 0 ]; then
      run_label="${edition}-${name}-run"
      bounded "$run_label" "$OUT/${run_label}.out" "$OUT/${run_label}.err" "$OUT/${run_label}.localrun.txt" "$TOOL/vvp" "$binary"
      run_rc=$?
      cat "$OUT/${run_label}.out"
    fi
  done
done
printf 'scratch=%s\n' "$TMP_ROOT" >"$EVIDENCE/scratch-path.txt"
