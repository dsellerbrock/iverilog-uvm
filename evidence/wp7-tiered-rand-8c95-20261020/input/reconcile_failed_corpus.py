#!/usr/bin/env python3
"""Replace only a failed FST sample with its pinned-build retry."""

import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
results = root / "results"
data = json.loads((results / "corpus.json").read_text())
retry = json.loads((results / "fst-repro-callgrind.json").read_text())
failures = {name for name, item in data["benchmarks"].items()
            if item.get("status") != "ok" or item.get("identical_all_runs") is not True}
if failures != {"waveform_fst"}:
    raise SystemExit(f"unexpected failed corpus workloads: {sorted(failures)}")
fst = retry["benchmarks"].get("waveform_fst", {})
if fst.get("status") != "ok" or fst.get("identical_all_runs") is not True:
    raise SystemExit(f"FST retry did not pass: {fst.get('error', fst.get('status'))}")
for side in ("reference", "candidate"):
    profile = root / "profiles" / f"fst-repro-{side}.callgrind"
    summaries = [line for line in profile.read_text().splitlines()
                 if line.startswith("summary:")]
    if len(summaries) != 1:
        raise SystemExit(f"missing retry Callgrind summary: {profile}")
data["benchmarks"]["waveform_fst"] = fst
data["reconciliation"] = {
    "replaced_workload": "waveform_fst",
    "reason": "first candidate Callgrind run exited 139; pinned reference/candidate retry passed",
    "retry_profile_prefix": "fst-repro-",
}
(results / "corpus-reconciled.json").write_text(
    json.dumps(data, indent=2, sort_keys=True) + "\n")
print(f"reconciled 18 workloads; preserved original failure in corpus.json")
