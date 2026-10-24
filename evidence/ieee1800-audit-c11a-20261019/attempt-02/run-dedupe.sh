#!/bin/bash
set -eu
OUT=evidence/ieee1800-audit-c11a-20261019/attempt-02
mkdir -p "$OUT"
for term in 'real operand' 'real modulus' 'real shift' 'real bitwise' 'integral operator real'; do
  slug=$(printf '%s' "$term" | tr ' ' '_')
  gh issue list --repo dsellerbrock/iverilog-uvm --state all --search "$term" --limit 40 --json number,title,state,url > "$OUT/dedupe_$slug.json"
done
jq -s 'add | unique_by(.number) | sort_by(.number)' "$OUT"/dedupe_*.json > "$OUT/dedupe-sorted.json"
jq -r '.[] | "#\(.number) [\(.state)] \(.title)"' "$OUT/dedupe-sorted.json" > "$OUT/dedupe-sorted.txt"
cat "$OUT/dedupe-sorted.txt"
