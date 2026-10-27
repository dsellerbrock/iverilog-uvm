#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
for term in '"6.22.3"' '"6.22.4"' '"6.22.6"' 'assignment-compatible' 'integral to enum' 'enum assignment' 'cast-compatible' 'cast to enum' 'nettype' 'user-defined nettype' 'nettype alias' 'nettype port' 'matching nettypes' 'matching nettype' 'mismatched nettype' 'nonmatching nettype' 'user-defined nettype port' 'nettype port connection' 'nettype mismatch' 'same data type nettype'; do
  printf '\n--- %s ---\n' "$term"
  gh issue list --repo dsellerbrock/iverilog-uvm --state all --search "$term" --limit 100 --json number,state,title,url --jq '.[] | "#\(.number) \(.state) \(.title) \(.url)"'
done
