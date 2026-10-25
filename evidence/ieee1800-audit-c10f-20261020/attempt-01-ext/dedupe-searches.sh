#!/usr/bin/env bash
set -euo pipefail
terms=("sign extension assignment" "truncation" "assignment-like context" "pattern argument" "10.7" "10.8" "cast assignment pattern" "assignment-like context cast" "\$bits" "bits system function" "20.6" "bits cast")
for term in "${terms[@]}"; do
  slug=$(printf '%s' "$term" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
  gh issue list --repo dsellerbrock/iverilog-uvm --state all --search "$term" --limit 100 --json number,title,state,url >"$(dirname "$0")/dedupe-${slug}.json"
done
