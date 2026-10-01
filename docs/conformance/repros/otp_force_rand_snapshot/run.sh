#!/bin/sh
set -eu

repo=$(CDPATH= cd "$(dirname "$0")/../../../.." && pwd)
iverilog=${IVERILOG:-$repo/local-install/bin/iverilog}
vvp=${VVP:-$repo/local-install/bin/vvp}
source_file=$repo/docs/conformance/repros/otp_force_rand_snapshot/repro.sv
tmp=$(mktemp -d "${TMPDIR:-/tmp}/otp-force-rand.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

for edition in 2017 2023; do
  for variant in original snapshot; do
    set --
    if [ "$variant" = snapshot ]; then set -- -DSNAPSHOT_UNSAFE; fi
    "$iverilog" -g"$edition" -gno-icarus-misc -gno-xtypes "$@" \
      -o "$tmp/$edition-$variant.vvp" "$source_file" \
      > "$tmp/$edition-$variant.compile" 2>&1
    "$vvp" -n "$tmp/$edition-$variant.vvp" \
      > "$tmp/$edition-$variant.run" 2>&1
    count=$(awk '/vvp.tgt sorry: procedural continuous assignments/ {n++}
                 END {print n+0}' "$tmp/$edition-$variant.compile")
    if [ "$variant" = original ]; then
      [ "$count" -eq 4 ]
    else
      [ "$count" -eq 0 ]
      grep -F -x -q 'UNSAFE: old force changed before replacement' \
        "$tmp/$edition-$variant.run"
    fi
    grep -F -x -q 'PASS: draws=8 locks=a5 a6 a7 a8' \
      "$tmp/$edition-$variant.run"
    echo "$edition $variant: $count semantic notices; expected runtime observed"
  done
done
