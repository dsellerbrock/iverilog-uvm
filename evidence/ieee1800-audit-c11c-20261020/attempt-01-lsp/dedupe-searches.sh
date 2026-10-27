#!/usr/bin/env bash
set -euo pipefail
out=$(cd "$(dirname "$0")" && pwd)
for term in 'longest static prefix' 'always_comb multiple drivers' 'always_comb written by another process' '11.5.3'; do
  safe=$(printf '%s' "$term" | tr ' /.' '___' | tr -cd '[:alnum:]_-')
  gh issue list --repo dsellerbrock/iverilog-uvm --state all --search "$term" --limit 100 --json number,title,state,url > "$out/dedupe-$safe.json"
done
