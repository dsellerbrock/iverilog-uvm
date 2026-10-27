#!/usr/bin/env bash
set -euo pipefail
out=$(cd "$(dirname "$0")" && pwd)
for term in '$timeunit' '$timeprecision' '20.4.1'; do
  safe=$(printf '%s' "$term" | tr ' /.' '___' | tr -cd '[:alnum:]_-')
  gh issue list --repo dsellerbrock/iverilog-uvm --state all --search "$term" --limit 100 --json number,title,state,url > "$out/dedupe-$safe.json"
done
