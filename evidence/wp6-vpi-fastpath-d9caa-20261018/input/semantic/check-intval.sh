#!/usr/bin/env bash
set -Eeuo pipefail
REF=$1
CAND=$2
INPUT=$3
OUT=$4
mkdir -p "$OUT/plugin"
"$REF/bin/iverilog" -g2012 -o "$OUT/intval_semantics.vvp" "$INPUT/intval_semantics.sv"
(
  cd "$OUT/plugin"
  "$REF/bin/iverilog-vpi" --name=intval_semantics "$INPUT/intval_semantics.c"
) > "$OUT/plugin-build.log" 2>&1
test -s "$OUT/plugin/intval_semantics.vpi"
"$REF/bin/vvp" -M "$OUT/plugin" -m intval_semantics "$OUT/intval_semantics.vvp" > "$OUT/reference.out" 2>&1
"$CAND/bin/vvp" -M "$OUT/plugin" -m intval_semantics "$OUT/intval_semantics.vvp" > "$OUT/candidate.out" 2>&1
grep -Fxq 'PASS vpiIntVal conversion' "$OUT/reference.out"
grep -Fxq 'PASS vpiIntVal conversion' "$OUT/candidate.out"
cmp "$OUT/reference.out" "$OUT/candidate.out"
printf 'PASS: baseline and candidate VPI integer values match\n'
