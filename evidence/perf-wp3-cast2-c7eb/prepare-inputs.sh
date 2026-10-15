#!/usr/bin/env bash
set -euo pipefail

EVIDENCE=$(CDPATH= cd "$(dirname "$0")" && pwd)
REPO=$(CDPATH= cd "$EVIDENCE/../.." && pwd)
BASE=c7ebca768c21c251d9c165c9aff0e363768030b1
UVM_CORE=78c06547a2a0a29b3dc9dcafae62b75b2ff61544
TMP=$(mktemp -d "${TMPDIR:-/tmp}/a5-wp3-inputs.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

test "$(git -C "$REPO" rev-parse "$BASE")" = "$BASE"
test "$(git -C "$REPO/uvm-core" rev-parse HEAD)" = "$UVM_CORE"
mkdir -p "$TMP/reference" "$TMP/candidate"
git -C "$REPO" archive --format=tar "$BASE" | tar -xf - -C "$TMP/reference"
git -C "$REPO" archive --format=tar "$BASE" | tar -xf - -C "$TMP/candidate"
mkdir -p "$TMP/reference/uvm-core" "$TMP/candidate/uvm-core"
git -C "$REPO/uvm-core" archive --format=tar "$UVM_CORE" \
  | tar -xf - -C "$TMP/reference/uvm-core"
git -C "$REPO/uvm-core" archive --format=tar "$UVM_CORE" \
  | tar -xf - -C "$TMP/candidate/uvm-core"

for path in vvp/vthread.cc vvp/vvp_net.h ivtest/regress-sv.list; do
  cp "$REPO/$path" "$TMP/candidate/$path"
done
cp "$REPO/ivtest/ivltests/sv_cast2_4state.v" \
  "$TMP/candidate/ivtest/ivltests/sv_cast2_4state.v"
cp "$REPO/ivtest/ivltests/sv_cast2_4state.v" \
  "$TMP/reference/ivtest/ivltests/sv_cast2_4state.v"

tar -czf "$EVIDENCE/reference-source.tar.gz" -C "$TMP/reference" .
tar -czf "$EVIDENCE/candidate-source.tar.gz" -C "$TMP/candidate" .
{
  printf 'measurement_base=%s\nuvm_core=%s\n' "$BASE" "$UVM_CORE"
  sha256sum "$EVIDENCE/reference-source.tar.gz" \
    "$EVIDENCE/candidate-source.tar.gz"
} > "$EVIDENCE/input-manifest.txt"
cat "$EVIDENCE/input-manifest.txt"
