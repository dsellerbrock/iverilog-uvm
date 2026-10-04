#!/usr/bin/env python3
"""Sample the isolated five-hour-capped Flash VVP run at selected phases."""

from __future__ import annotations

import datetime as dt
import json
from pathlib import Path
import subprocess
import time


BUILD_ROOT = Path("/private/tmp/pi/census12/flash-default-five-hour-retry")
RESULT_JSON = Path(__file__).resolve().parent / "result-flash-five-hour-default.json"
ROOT = Path(__file__).resolve().parent
SAMPLE_AT = (30, 180, 900, 1800, 2700, 3600, 4500, 4800, 5100, 5400,
             6000, 7200, 9000, 12000, 15000, 18000)
POLL_SECONDS = 15
CORE = "lowrisc_dv_flash_ctrl_sim_0.1"
PROGRESS = ROOT / "flash-default-profile-samples.jsonl"


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


def live_vvp_processes() -> list[tuple[int, str, int]]:
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
        pid = int(fields[0])
        started = " ".join(fields[1:6])
        age = elapsed_seconds(fields[6])
        command = fields[7]
        if Path(command.split(maxsplit=1)[0]).name != "vvp":
            continue
        if str(BUILD_ROOT) not in command or "matrix-runtime.vvp" not in command:
            continue
        if f"/runtime/{CORE}/matrix-runtime.vvp" not in command:
            continue
        found.append((pid, started, age))
    return found


def main() -> int:
    captured: set[tuple[int, str, int]] = set()
    saw_target = False
    with PROGRESS.open("w", buffering=1) as progress:
        started = dt.datetime.now(dt.timezone.utc).isoformat()
        progress.write(json.dumps({"event": "started", "utc": started}) + "\n")
        print(json.dumps({"event": "started", "utc": started}), flush=True)
        while True:
            processes = live_vvp_processes()
            if processes:
                saw_target = True
            for pid, process_started, age in processes:
                for threshold in SAMPLE_AT:
                    key = (pid, process_started, threshold)
                    if age < threshold or key in captured:
                        continue
                    filename = f"{CORE}-after-{threshold}s-pid{pid}.sample.txt"
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
                        "core": CORE,
                        "pid": pid,
                        "age_seconds": age,
                        "scheduled_after_seconds": threshold,
                        "returncode": sample.returncode,
                        "bytes": output.stat().st_size if output.exists() else 0,
                        "path": filename,
                        "stderr": sample.stderr[-1000:],
                    }
                    progress.write(json.dumps(item) + "\n")
                    print(json.dumps(item), flush=True)
            if saw_target and not processes:
                break
            if RESULT_JSON.exists() and not processes:
                break
            time.sleep(POLL_SECONDS)
        finished = dt.datetime.now(dt.timezone.utc).isoformat()
        item = {"event": "finished", "utc": finished, "sample_count": len(captured)}
        progress.write(json.dumps(item) + "\n")
        print(json.dumps(item), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
