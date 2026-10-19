#!/bin/bash
set -euo pipefail
TMP=/tmp/a3-672-t0-clean
WORKTREE=/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-issue672-param-config-path-20261018
mkdir -p "$TMP/src"
git -C "$WORKTREE" archive HEAD | tar -x -C "$TMP/src"
cd "$TMP/src"
export PATH="/opt/homebrew/opt/bison/bin:$PATH"
export CPPFLAGS="$(pkg-config --cflags libffi z3)"
export LDFLAGS="$(pkg-config --libs-only-L libffi z3)"
autoconf > "$TMP/autoconf.log" 2>&1
./configure --enable-libveriuser --prefix="$PWD/local-install" > "$TMP/configure.log" 2>&1
make -j3 > "$TMP/build.log" 2>&1
make install > "$TMP/install.log" 2>&1
PATH="$PWD/local-install/bin:$PATH" ./ci/run-smoke.sh > "$TMP/smoke.log" 2>&1
printf 'T0 smoke complete\n'
tail -n 40 "$TMP/smoke.log"
PATH="$PWD/local-install/bin:$PATH" iverilog -V | head -n 4
shasum -a 256 local-install/bin/iverilog local-install/bin/vvp
