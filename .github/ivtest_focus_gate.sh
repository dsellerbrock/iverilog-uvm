#!/usr/bin/env bash
# Hard-gate one paired legacy/JSON ivtest feature focus.
#
# The broad regression remains soft on platforms with recorded unrelated
# failures. This gate gives a feature PR a small, zero-tolerance cross-platform
# lane without converting those historical failures into a blanket waiver.

set -eu

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <legacy-list> <json-list>" >&2
    exit 2
fi

ROOT=$(cd "$(dirname "$0")/.." && pwd)
LEGACY_LIST=$1
JSON_LIST=$2

cd "$ROOT/ivtest"

if [ ! -f "$LEGACY_LIST" ]; then
    echo "focused legacy manifest not found: $LEGACY_LIST" >&2
    exit 2
fi
if [ ! -f "$JSON_LIST" ]; then
    echo "focused JSON manifest not found: $JSON_LIST" >&2
    exit 2
fi

echo "=== focused legacy ivtest: $LEGACY_LIST ==="
perl ./vvp_reg.pl "$LEGACY_LIST"

echo ""
echo "=== focused JSON/VVP ivtest: $JSON_LIST ==="
python3 ./vvp_reg.py "$JSON_LIST"
