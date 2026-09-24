#!/usr/bin/env python3
"""Check the L0 runner's error and checker-sampling rejection rules."""

from pathlib import Path
import runpy

here = Path(__file__).resolve().parent
runner = runpy.run_path(str(here / "run.py"), run_name="runner_check")
bad = runner["BAD"]
assert all(bad.search(text) for text in (
    "ERROR", "unexpected interrupt ERROR", "UVM_ERROR: test",
    "FATAL: stop", "assertion failed"))
assert not bad.search("* TESTCASE PASSED")
compile_log = here.parent / "caliptra-l0-icarus-baseline-20260923/profile.stderr.log"
assert len(runner["SAMPLING_WARNING"].findall(compile_log.read_text())) == 32
print("runner diagnostic guards: PASS")
