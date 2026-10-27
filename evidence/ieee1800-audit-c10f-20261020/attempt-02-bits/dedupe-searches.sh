#!/usr/bin/env bash
set -euo pipefail
terms=("\$bits" "bits unpacked struct" "20.6.2")
for term in "${terms[@]}"; do
  slug=$(printf '%s' "$term" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
  gh issue list --repo dsellerbrock/iverilog-uvm --state all --search "$term" --limit 100 --json number,title,state,url >"$(dirname "$0")/dedupe-${slug}.json"
done
