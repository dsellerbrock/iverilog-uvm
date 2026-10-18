#!/bin/sh
set -eu

if [ "$#" -ne 4 ]; then
    echo "usage: $0 REF_IVERILOG REF_VVP CAND_IVERILOG CAND_VVP" >&2
    exit 2
fi

ref_iverilog=$1
ref_vvp=$2
cand_iverilog=$3
cand_vvp=$4
fixture=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/sparse_mul.sv
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

"$ref_iverilog" -g2012 -o "$tmp/ref.vvp" "$fixture"
"$cand_iverilog" -g2012 -o "$tmp/cand.vvp" "$fixture"
"$ref_vvp" "$tmp/ref.vvp" > "$tmp/ref.out"
"$cand_vvp" "$tmp/cand.vvp" > "$tmp/cand.out"
diff -u "$tmp/ref.out" "$tmp/cand.out"
cat "$tmp/cand.out"
