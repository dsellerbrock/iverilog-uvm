#!/usr/bin/env bash
# install_ivl.sh — refresh local install/ tree after a build.
#
# `make install` configures with prefix=/usr/local, so it tries to write
# to /usr/local/lib/ivl/ivl (root-only).  The driver computes its module
# path via find_ivl_root() relative to its own location, landing at
# install/lib/ivl/ivl — but `make install` never updates that copy.
# This script does the right thing locally for the four binaries that
# matter when iterating on iverilog/vvp itself.
#
# Run after every `make` in iverilog/ that touches ivl, vvp, or driver/.

set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"   # iverilog source root
INST="$SRC/install"

if [[ ! -d "$INST/lib/ivl" || ! -d "$INST/bin" ]]; then
      echo "error: $INST is not a populated install tree." >&2
      echo "       run a full \`make install DESTDIR=$INST\` once first." >&2
      exit 1
fi

install -m 755 "$SRC/ivl"             "$INST/lib/ivl/ivl"
install -m 755 "$SRC/ivl"             "$INST/bin/ivl"
install -m 755 "$SRC/vvp/vvp"         "$INST/bin/vvp"
install -m 755 "$SRC/driver/iverilog" "$INST/bin/iverilog"
install -m 755 "$SRC/tgt-vvp/vvp.tgt" "$INST/lib/ivl/vvp.tgt"

printf 'installed:\n'
for f in "$INST/lib/ivl/ivl" "$INST/bin/ivl" "$INST/bin/vvp" "$INST/bin/iverilog" "$INST/lib/ivl/vvp.tgt"; do
      printf '  %s (%s)\n' "$f" "$(stat -c %y "$f" | cut -d. -f1)"
done
