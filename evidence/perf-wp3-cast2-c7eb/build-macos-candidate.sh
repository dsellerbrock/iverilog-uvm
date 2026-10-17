#!/usr/bin/env bash
set -euo pipefail

EVIDENCE=$(CDPATH= cd "$(dirname "$0")" && pwd)
REPO=$(CDPATH= cd "$EVIDENCE/../.." && pwd)
OUT="$EVIDENCE/macos-gates"
PREFIX="$REPO/local-install"

test "$(uname -m)" = arm64
test ! -e "$PREFIX"
mkdir -p "$OUT"
export PATH="/opt/homebrew/opt/bison/bin:/opt/homebrew/bin:$PATH"
export CPPFLAGS="-I/opt/homebrew/opt/libffi/include -I/opt/homebrew/opt/z3/include"
export LDFLAGS="-L/opt/homebrew/opt/libffi/lib -L/opt/homebrew/opt/z3/lib"
export CFLAGS='-g0 -O2'
export CXXFLAGS='-g0 -O2'

{
  uname -a
  bison --version | sed -n '1p'
  g++ --version | sed -n '1p'
  git -C "$REPO" rev-parse HEAD
  git -C "$REPO" rev-parse c7ebca768c21c251d9c165c9aff0e363768030b1
  git -C "$REPO/uvm-core" rev-parse HEAD
} > "$OUT/environment.txt"

cd "$REPO"
sh autoconf.sh > "$OUT/autoconf.log" 2>&1
./configure --prefix="$PREFIX" --enable-libveriuser \
  > "$OUT/configure.log" 2>&1
make -j1 YACC=/opt/homebrew/opt/bison/bin/bison LEX=/usr/bin/flex \
  > "$OUT/build.log" 2>&1
make install > "$OUT/install.log" 2>&1
make installuvm > "$OUT/installuvm.log" 2>&1
shasum -a 256 "$PREFIX/bin/iverilog" "$PREFIX/bin/vvp" \
  "$PREFIX/bin/iverilog-vpi" > "$OUT/tool-sha256.txt"
