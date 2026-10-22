#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR=/tmp/a3-1800-audit-c06j-20261020-build
cd "$BUILD_DIR"
export CPPFLAGS='-I/opt/homebrew/opt/libffi/include -I/opt/homebrew/opt/z3/include'
export LDFLAGS='-L/opt/homebrew/opt/libffi/lib -L/opt/homebrew/opt/z3/lib'
PATH="/opt/homebrew/opt/bison/bin:$PATH" "$ROOT/configure" --prefix="$BUILD_DIR/install"
PATH="/opt/homebrew/opt/bison/bin:$PATH" make -j3
PATH="/opt/homebrew/opt/bison/bin:$PATH" make install
