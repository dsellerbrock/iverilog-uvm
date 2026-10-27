#!/usr/bin/env bash
set -euo pipefail
terms=("constant function" "aggregate equality" "unpacked array ==" "struct ==" "11.2.2" "conditional unpacked")
for term in "${terms[@]}"; do
  slug=$(printf '%s' "$term" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
  gh issue list --repo dsellerbrock/iverilog-uvm --state all --search "$term" --limit 100 --json number,title,state,url >"$(dirname "$0")/dedupe-${slug}.json"
done
