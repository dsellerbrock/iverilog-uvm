#!/usr/bin/env bash
set -euo pipefail
out=$(cd "$(dirname "$0")" && pwd)/dedupe
mkdir -p "$out"
terms=("unpacked array concatenation" "queue concatenation" "empty concatenation" "10.10" "nested unpacked array concatenation" "nested string concatenation" "array concatenation string")
for term in "${terms[@]}"; do
  slug=$(printf '%s' "$term" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-')
  gh issue list --repo dsellerbrock/iverilog-uvm --state all --limit 1000 --search "$term" --json number,title,state,url >"$out/$slug.json"
done
python3 - "$out" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
with (root.parent / 'dedupe-results.md').open('w') as out:
    out.write('# Open and closed issue dedupe: IEEE 1800 §10.10\n\n')
    for path in sorted(root.glob('*.json')):
        hits = json.loads(path.read_text())
        out.write(f'## {path.stem}\n\n')
        if not hits:
            out.write('No matches.\n\n')
            continue
        for issue in hits:
            out.write(f"- #{issue['number']} ({issue['state']}): {issue['title']} — {issue['url']}\n")
        out.write('\n')
PY
