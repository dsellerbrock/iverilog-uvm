#!/usr/bin/env bash
set -euo pipefail

MODE=${1:?baseline or fixed}
SOURCE_SHA=${2:?source commit}
autoconf
./configure --prefix="$PWD/local-install"
make -j3
make install
SOURCE_SHA="$SOURCE_SHA" bash evidence/m9-issue759-chandle-20261024/run-probes-and-collateral.sh "$MODE"
