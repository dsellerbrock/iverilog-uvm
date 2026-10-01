#!/usr/bin/env python3
"""Small process-group control for the Caliptra VVP memory watchdog."""

import importlib.util
import os
from pathlib import Path
import sys
import tempfile

spec = importlib.util.spec_from_file_location("caliptra_runner", Path(__file__).with_name("run.py"))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    env = os.environ.copy()
    code, timed_out, memory_hit, peak = runner.invoke(
        [sys.executable, "-c", "print('ok')"], root, env, root / "pass.log", 10,
        memory_cap_bytes=256 * 1024**2)
    assert (code, timed_out, memory_hit) == (0, False, False)

    code, timed_out, memory_hit, peak = runner.invoke(
        [sys.executable, "-c",
         "import time; data=bytearray(128*1024*1024); print('ready', flush=True); time.sleep(20)"],
        root, env, root / "cap.log", 20, memory_cap_bytes=32 * 1024**2)
    assert code < 0 and not timed_out and memory_hit, (code, timed_out, memory_hit)
    assert peak is not None and peak > 32 * 1024**2

    code, timed_out, memory_hit, peak = runner.invoke(
        [sys.executable, "-c", "import time; time.sleep(20)"],
        root, env, root / "timeout.log", 1, memory_cap_bytes=256 * 1024**2)
    assert (code, timed_out, memory_hit) == (None, True, False)

print("PASSED: normal exit, memory cap, and timeout stay distinct")
