#!/usr/bin/env python3
"""Capture native samples from Census 12 VVP jobs that run long enough."""

from __future__ import annotations

import datetime as dt
import json
from pathlib import Path
import re
import subprocess
import sys
import time


BUILD_ROOT = Path("/private/tmp/pi/census12/build")
ROOT = Path(__file__).resolve().parent
SAMPLE_AT = (120, 900)
POLL_SECONDS = 15
PROGRESS = ROOT / "hotpath-samples.jsonl"


def elapsed_seconds(value: str) -> int:
    days = 0
    if "-" in value:
        day_text, value = value.split("-", 1)
        days = int(day_text)
    pieces = [int(part) for part in value.split(":")]
    if len(pieces) == 3:
        hours, minutes, seconds = pieces
    elif len(pieces) == 2:
        hours, (minutes, seconds) = 0, pieces
    else:
        hours, minutes, seconds = 0, 0, pieces[0]
    return days * 86400 + hours * 3600 + minutes * 60 + seconds


def live_vvp_processes() -> list[tuple[int, str, int, str]]:
    result = subprocess.run(
        ["/bin/ps", "-axo", "pid=,lstart=,etime=,command="],
        text=True,
        capture_output=True,
        check=False,
    )
    found = []
    for line in result.stdout.splitlines():
        fields = line.split(maxsplit=7)
        if len(fields) < 8:
            continue
        pid, started, elapsed, command = (
            int(fields[0]), " ".join(fields[1:6]), fields[6], fields[7]
        )
        if str(BUILD_ROOT) not in command or "matrix-runtime.vvp" not in command:
            continue
        match = re.search(
            re.escape(str(BUILD_ROOT)) + r"/runtime/([^/]+)/matrix-runtime\.vvp",
            command,
        )
        if match:
            found.append((pid, started, elapsed_seconds(elapsed), match.group(1)))
    return found


def main() -> int:
    captured: set[tuple[int, str, int]] = set()
    with PROGRESS.open("w", buffering=1) as progress:
        started = dt.datetime.now(dt.timezone.utc).isoformat()
        progress.write(json.dumps({"event": "started", "utc": started}) + "\n")
        print(json.dumps({"event": "started", "utc": started}), flush=True)
        try:
            while True:
                for pid, process_started, age, core in live_vvp_processes():
                    for threshold in SAMPLE_AT:
                        key = (pid, process_started, threshold)
                        if age < threshold or key in captured:
                            continue
                        filename = f"{core}-after-{threshold}s-pid{pid}.sample.txt"
                        output = ROOT / filename
                        sample = subprocess.run(
                            ["/usr/bin/sample", str(pid), "10", "1", "-fullPaths",
                             "-file", str(output)],
                            text=True,
                            capture_output=True,
                            check=False,
                        )
                        captured.add(key)
                        item = {
                            "event": "sample",
                            "core": core,
                            "pid": pid,
                            "process_started": process_started,
                            "age_seconds": age,
                            "scheduled_after_seconds": threshold,
                            "returncode": sample.returncode,
                            "bytes": output.stat().st_size if output.exists() else 0,
                            "path": filename,
                            "stderr": sample.stderr[-1000:],
                        }
                        progress.write(json.dumps(item) + "\n")
                        print(json.dumps(item), flush=True)
                time.sleep(POLL_SECONDS)
        except KeyboardInterrupt:
            pass
        finished = dt.datetime.now(datetime.timezone.utc).isoformat()
        result = {
            "event": "finished",
            "utc": finished,
            "sample_count": len(captured),
        }
        progress.write(json.dumps(result) + "\n")
        print(json.dumps(result), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
