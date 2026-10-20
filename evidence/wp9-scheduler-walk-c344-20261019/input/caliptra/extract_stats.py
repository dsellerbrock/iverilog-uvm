#!/usr/bin/env python3
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
rows = []
for case in ("smoke_test_dma_aes_gcm_short_1_dword", "smoke_test_sha256", "cptra_ss_test_rom"):
    log = root / "logs" / case / "sim.log"
    lines = [line for line in log.read_text(errors="replace").splitlines()
             if line.startswith("VVP_PERF_STATS ")]
    if len(lines) != 1:
        raise SystemExit(f"{case}: expected one perf-stats line, got {len(lines)}")
    stats = json.loads(lines[0][len("VVP_PERF_STATS "):])
    row = {"test": case, "scheduler_time_list": stats["scheduler_time_list"],
           "thread_wakes": stats["thread_wakes"],
           "events_by_region": stats["events_by_region"]}
    rows.append(row)
(root / "scheduler-counters.json").write_text(json.dumps(rows, indent=2) + "\n")
with (root / "scheduler-counters.csv").open("w") as out:
    out.write("test,insertions,total_steps,max_steps,average_steps,thread_wakes\n")
    for row in rows:
        q = row["scheduler_time_list"]
        average = q["total_steps"] / q["insertions"] if q["insertions"] else 0
        out.write(f"{row['test']},{q['insertions']},{q['total_steps']},{q['max_steps']},{average:.6f},{row['thread_wakes']}\n")
