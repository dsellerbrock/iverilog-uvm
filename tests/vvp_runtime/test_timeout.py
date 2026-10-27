#!/usr/bin/env python3
"""Run one test command with a wall-clock limit for its whole process group."""

import os
import signal
import subprocess
import sys


def terminate_group(process):
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        return process.communicate()
    try:
        return process.communicate(timeout=2)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        return process.communicate()


def main():
    if len(sys.argv) < 3:
        raise SystemExit("usage: run_test_timeout.py SECONDS COMMAND [ARG ...]")
    timeout = float(sys.argv[1])
    process = subprocess.Popen(
        sys.argv[2:], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        start_new_session=True,
    )
    timed_out = False
    try:
        stdout, stderr = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        stdout, stderr = terminate_group(process)
    sys.stdout.buffer.write(stdout)
    sys.stderr.buffer.write(stderr)
    if timed_out:
        print(f"test timed out after {timeout:g}s", file=sys.stderr)
        return 124
    return process.returncode


if __name__ == "__main__":
    raise SystemExit(main())
