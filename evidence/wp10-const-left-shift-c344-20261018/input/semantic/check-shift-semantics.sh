#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: $0 <reference-iverilog> <reference-vvp> <candidate-iverilog> <candidate-vvp>" >&2
  exit 2
fi

here=$(cd -- "$(dirname -- "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

"$1" -g2012 -o "$tmp/reference.vvp" "$here/shift_semantics.sv"
"$3" -g2012 -o "$tmp/candidate.vvp" "$here/shift_semantics.sv"
grep -Eq '\.shift/l 32,' "$tmp/candidate.vvp"
reference_shifts=$(grep -c '\.shift/l 32,' "$tmp/reference.vvp" || true)
candidate_shifts=$(grep -c '\.shift/l 32,' "$tmp/candidate.vvp" || true)
if (( candidate_shifts <= reference_shifts )); then
  echo "candidate did not emit an additional constant-shift functor" >&2
  exit 1
fi
reference_parts=$(grep -c '\.part' "$tmp/reference.vvp" || true)
candidate_parts=$(grep -c '\.part' "$tmp/candidate.vvp" || true)
if (( candidate_parts == 0 || candidate_parts >= reference_parts )); then
  echo "candidate did not preserve the named part while removing private parts" >&2
  exit 1
fi
"$2" "$tmp/reference.vvp" >"$tmp/reference.out" 2>"$tmp/reference.err"
"$4" "$tmp/candidate.vvp" >"$tmp/candidate.out" 2>"$tmp/candidate.err"
cmp "$tmp/reference.out" "$tmp/candidate.out"
cmp "$tmp/reference.err" "$tmp/candidate.err"
