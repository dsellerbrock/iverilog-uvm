#!/usr/bin/env python3
"""Run a command with a wall-clock limit and terminate its process group."""

import os
import signal
import subprocess
import sys
import time


def main() -> int:
    if len(sys.argv) < 4 or sys.argv[2] != "--" or not sys.argv[3:]:
        print("usage: run_with_timeout.py SECONDS -- COMMAND [ARG ...]", file=sys.stderr)
        return 2
    timeout = float(sys.argv[1])
    command = sys.argv[3:]

    process = subprocess.Popen(
        command,
        creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0,
        start_new_session=os.name != "nt",
    )
    try:
        return process.wait(timeout=max(0, timeout))
    except subprocess.TimeoutExpired:
        print(f"Timed out after {timeout:.1f}s: {' '.join(command)}", file=sys.stderr)
        if os.name == "nt":
            try:
                process.send_signal(signal.CTRL_BREAK_EVENT)
            except OSError:
                pass
            time.sleep(2)
            if process.poll() is None:
                subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                               check=False)
        else:
            os.killpg(process.pid, signal.SIGTERM)
            term_sent = time.monotonic()
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                pass
            time.sleep(max(0, 2 - (time.monotonic() - term_sent)))
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        process.wait()
        return 124


if __name__ == "__main__":
    raise SystemExit(main())
