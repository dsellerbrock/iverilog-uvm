#!/bin/bash
set -euo pipefail
BUILD_DIR=/tmp/a3-1800-audit-c06j-20261020-build
cd "$BUILD_DIR"
make -j3 \
  CPPFLAGS='-I/opt/homebrew/opt/libffi/include -I/opt/homebrew/opt/z3/include' \
  LDFLAGS='-L/opt/homebrew/opt/libffi/lib -L/opt/homebrew/opt/z3/lib'
make install
