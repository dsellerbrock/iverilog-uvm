#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
LOCK="$HOME/slurm-runs/iverilog-uvm/a4/nightly-control.lock"
LOGS="$HOME/slurm-runs/iverilog-uvm/a4/nightly-control-logs"
mkdir -p "$(dirname "$LOCK")" "$LOGS" "$HOME/codex-supervisor"
exec 9>"$LOCK"
flock -n 9 || exit 0

if [[ -n $(git -C "$ROOT" status --porcelain) ]]; then
    echo "Nightly control checkout is dirty: $ROOT" >&2
    exit 1
fi
git -C "$ROOT" fetch --quiet origin main
git -C "$ROOT" checkout --detach origin/main
sha=$(git -C "$ROOT" rev-parse HEAD)
if ! result=$(sbatch --export=ALL,MAIN_SHA="$sha" \
    --output="$LOGS/nightly-main-%j.out" "$ROOT/ci/nightly-main.sbatch" 2>&1); then
    python3 - "$HOME/codex-supervisor/nightly-main.json" "$sha" "$result" <<'PY'
import json
import os
import sys
import tempfile
from datetime import datetime, timezone

path, sha, error = sys.argv[1:]
value = {"sha": sha,
         "date": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
         "passed": False,
         "failed": "sbatch: " + error, "log": None}
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".nightly-main-")
with os.fdopen(fd, "w") as stream:
    json.dump(value, stream, indent=2)
    stream.write("\n")
os.replace(tmp, path)
PY
    exit 1
fi
echo "$result for main $sha"
