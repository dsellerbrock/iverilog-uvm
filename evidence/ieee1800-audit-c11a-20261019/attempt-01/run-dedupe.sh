#!/bin/bash
set -eu
OUT=evidence/ieee1800-audit-c11a-20261019/attempt-01
mkdir -p "$OUT"
for term in 'power operator' modulus 'wildcard equality' 'logical implication' 'assignment operator' 'increment operator' 'short circuit' 'signed division' 'arithmetic x' 'equivalence operator'; do
  slug=$(printf '%s' "$term" | tr ' ' '_')
  gh issue list --repo dsellerbrock/iverilog-uvm --state all --search "$term" --limit 40 --json number,title,state,url > "$OUT/dedupe_$slug.json"
done
jq -s 'add | unique_by(.number) | sort_by(.number)' "$OUT"/dedupe_*.json > "$OUT/dedupe-sorted.json"
jq -r '.[] | "#\(.number) [\(.state)] \(.title)"' "$OUT/dedupe-sorted.json" > "$OUT/dedupe-sorted.txt"
cat "$OUT/dedupe-sorted.txt"
