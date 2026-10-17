#!/usr/bin/env python3
"""Run regress-vvp entries individually with process-group timeouts."""
import argparse
import csv
import os
import pathlib
import re
import subprocess
import sys
import time

parser = argparse.ArgumentParser()
parser.add_argument("--source", required=True, type=pathlib.Path)
parser.add_argument("--install", required=True, type=pathlib.Path)
parser.add_argument("--output", required=True, type=pathlib.Path)
parser.add_argument("--names-file", type=pathlib.Path)
parser.add_argument("--timeout-seconds", type=int, default=300)
args = parser.parse_args()

ivtest = args.source / "ivtest"
sys.path.insert(0, str(ivtest))
import test_lists  # noqa: E402

os.chdir(ivtest)
args.output.mkdir(parents=True, exist_ok=True)
lists_dir = args.output / "lists"
failures_dir = args.output / "failures"
lists_dir.mkdir(exist_ok=True)
failures_dir.mkdir(exist_ok=True)

tests = test_lists.read_lists(["regress-vvp.list"])
if args.names_file:
    wanted = {line.strip() for line in args.names_file.read_text().splitlines() if line.strip()}
    available = {item[0] for item in tests}
    missing = wanted - available
    if missing:
        raise SystemExit("missing from baseline manifest: " + ", ".join(sorted(missing)))
    tests = [item for item in tests if item[0] in wanted]

env = os.environ.copy()
env["PATH"] = str(args.install / "bin") + os.pathsep + env.get("PATH", "")
env["IVERILOG"] = str(args.install / "bin" / "iverilog")
env["VVP"] = str(args.install / "bin" / "vvp")

failure_names = []
timeout_names = []
results_path = args.output / "results.tsv"
with results_path.open("w", newline="") as results:
    writer = csv.writer(results, delimiter="\t", lineterminator="\n")
    writer.writerow(["test", "exit_code", "wall_seconds", "result"])
    for index, item in enumerate(tests, start=1):
        name = item[0]
        list_path = lists_dir / (name + ".list")
        list_path.write_text(" ".join(item) + "\n")
        cmd = [
            "timeout", "--signal=TERM", "--kill-after=15s",
            f"{args.timeout_seconds}s", sys.executable, "./vvp_reg.py",
            str(list_path),
        ]
        started = time.monotonic()
        proc = subprocess.run(
            cmd, cwd=ivtest, env=env, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, errors="replace", check=False,
        )
        elapsed = time.monotonic() - started
        match = re.search(r"^\s*" + re.escape(name) + r":\s*(.*?)\s*$",
                          proc.stdout, re.MULTILINE)
        result = match.group(1) if match else "NO_RESULT_LINE"
        writer.writerow([name, proc.returncode, f"{elapsed:.3f}", result])
        if proc.returncode != 0:
            failure_names.append(name)
            (failures_dir / (name + ".log")).write_text(proc.stdout)
        if proc.returncode in (124, 137):
            timeout_names.append(name)
        if index % 100 == 0 or index == len(tests):
            print(f"progress={index}/{len(tests)} failures={len(failure_names)} "
                  f"timeouts={len(timeout_names)}", flush=True)

(args.output / "failures.txt").write_text(
    "".join(name + "\n" for name in failure_names)
)
(args.output / "timeouts.txt").write_text(
    "".join(name + "\n" for name in timeout_names)
)
(args.output / "summary.txt").write_text(
    f"ran={len(tests)}\nfailed={len(failure_names)}\ntimeouts={len(timeout_names)}\n"
)
if timeout_names:
    raise SystemExit(2)
