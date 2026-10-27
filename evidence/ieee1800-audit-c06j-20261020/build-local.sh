#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR=/tmp/a3-1800-audit-c06j-20261020-build
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
PATH="/opt/homebrew/opt/bison/bin:$PATH" "$ROOT/configure" --prefix="$BUILD_DIR/install"
PATH="/opt/homebrew/opt/bison/bin:$PATH" make -j3
