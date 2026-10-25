#!/bin/bash
set -euo pipefail
for term in '"10.5"' 'variable declaration assignment' 'variable initialization' 'declaration initialization' 'static variable initializer' 'variable initializer' 'initialization is not continuous assignment' 'net declaration initializer' 'initialized variable' 'static class member initialization'; do
  printf '\n--- %s ---\n' "$term"
  gh issue list --repo dsellerbrock/iverilog-uvm --state all --search "$term" --limit 100 --json number,state,title,url --jq '.[] | "#\(.number) \(.state) \(.title) \(.url)"'
done
