#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR=/tmp/a3-1800-audit-c06j-20261020-build
LIBFFI=/opt/homebrew/opt/libffi
cd "$BUILD_DIR"
make clean
export CPPFLAGS="-I$LIBFFI/include"
export LDFLAGS="-L$LIBFFI/lib"
PATH="/opt/homebrew/opt/bison/bin:$PATH" "$ROOT/configure" --prefix="$BUILD_DIR/install"
PATH="/opt/homebrew/opt/bison/bin:$PATH" make -j3
PATH="/opt/homebrew/opt/bison/bin:$PATH" make install
