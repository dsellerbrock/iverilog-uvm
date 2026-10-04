#!/usr/bin/env python3
"""Capture low-overhead native samples from the five-hour Flash replay."""

from __future__ import annotations

import datetime as dt
import json
from pathlib import Path
import subprocess
import time


ROOT = Path(__file__).resolve().parent
PID = 85402
VVP_PATH = "/Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-unsafe-syntax-20260926/vvp/vvp"
SAMPLE_AFTER_SECONDS = (300, 900, 2100, 4500, 8700, 16500)
progress_path = ROOT / "sample-progress.jsonl"
results = []
started = time.monotonic()
start_utc = dt.datetime.now(dt.timezone.utc).isoformat()
next_sample = 0


def live_command() -> str | None:
    result = subprocess.run(
        ["/bin/ps", "-p", str(PID), "-o", "command="],
        text=True,
        capture_output=True,
        check=False,
    )
    command = result.stdout.strip()
    return command if VVP_PATH in command else None


with progress_path.open("w", buffering=1) as progress:
    progress.write(json.dumps({"event": "started", "pid": PID,
                               "start_utc": start_utc}) + "\n")
    print(json.dumps({"event": "started", "pid": PID,
                      "start_utc": start_utc}), flush=True)
    while live_command() is not None:
        elapsed = time.monotonic() - started
        if (next_sample < len(SAMPLE_AFTER_SECONDS)
                and elapsed >= SAMPLE_AFTER_SECONDS[next_sample]):
            index = next_sample + 2  # the early sample was captured separately
            output = ROOT / f"flash-sample-followup-{index}.txt"
            before = time.monotonic()
            captured = subprocess.run(
                ["/usr/bin/sample", str(PID), "10", "1", "-fullPaths",
                 "-file", str(output)],
                text=True,
                capture_output=True,
                check=False,
            )
            item = {
                "event": "sample",
                "sample": index,
                "scheduled_after_seconds": SAMPLE_AFTER_SECONDS[next_sample],
                "elapsed_seconds": round(time.monotonic() - started, 1),
                "capture_seconds": round(time.monotonic() - before, 1),
                "returncode": captured.returncode,
                "bytes": output.stat().st_size if output.exists() else 0,
                "path": output.name,
                "stderr": captured.stderr[-1000:],
            }
            results.append(item)
            progress.write(json.dumps(item) + "\n")
            print(json.dumps(item), flush=True)
            next_sample += 1
            continue
        time.sleep(5)

finished_utc = dt.datetime.now(dt.timezone.utc).isoformat()
result = {
    "pid": PID,
    "start_utc": start_utc,
    "finish_utc": finished_utc,
    "duration_seconds": round(time.monotonic() - started, 1),
    "samples": results,
    "remaining_scheduled_samples": len(SAMPLE_AFTER_SECONDS) - next_sample,
}
(ROOT / "sample-result.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps({"event": "finished", **result}), flush=True)
