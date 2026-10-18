#!/usr/bin/env python3
"""Collect one perf-record profile for each sim-hotspots corpus workload."""

import gzip
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time


source = Path(sys.argv[1]).resolve()
root = Path(sys.argv[2]).resolve()
runner_path = source / "benchmarks/sim-hotspots/run_json.py"
spec = importlib.util.spec_from_file_location("sim_hotspots_json", runner_path)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
assert len(runner.BENCHMARKS) == 18

compiler = runner.command_words("IVERILOG", "iverilog")
runtime = os.environ["VVP_BIN"]
perf = shutil.which("perf")
if not compiler or not perf:
    raise SystemExit("iverilog and perf are required")

build_root = root / "build"
build_root.mkdir(parents=True, exist_ok=True)
profiles = root / "profiles"
reports = root / "reports"
profiles.mkdir(parents=True, exist_ok=True)
reports.mkdir(parents=True, exist_ok=True)
plugin_dir = runner.build_vpi_module(build_root)
cpu_affinity = runner.pin_one_cpu()
if not cpu_affinity:
    raise SystemExit("could not pin the corpus profile to one CPU")
env = os.environ.copy()
env["LC_ALL"] = "C"
env["PERF_PAGER"] = "cat"
summary = {"source": str(source), "cpu_affinity": cpu_affinity,
           "perf_version": subprocess.check_output([perf, "--version"], text=True).strip(),
           "benchmarks": {}}

for name in runner.BENCHMARKS:
    program = runner.compile_bench(name, build_root, compiler)
    run_dir = root / "runs" / name
    run_dir.mkdir(parents=True)
    input_dir = run_dir / ".inputs"
    input_dir.mkdir()
    runner.stage_inputs(name, input_dir)
    command = [*runner.runtime_arguments(name, runtime, plugin_dir), str(program)]
    if name == "randomize_dv_txn":
        command.append("+runs=400")
    if name == "waveform_fst":
        command.extend(["+use_fst", "-fst", "-no-date"])
    elif name == "waveform_vcd":
        command.extend(["+use_vcd", "-vcd", "-no-date"])

    profile = profiles / f"{name}.data"
    stdout = run_dir / "stdout.bin"
    started = time.monotonic()
    repeat_driver = """import subprocess, sys, time
command = sys.argv[1:]
deadline = time.monotonic() + 3.0
while True:
    result = subprocess.run(command, stdout=subprocess.DEVNULL,
                            stderr=subprocess.STDOUT)
    if result.returncode:
        raise SystemExit(result.returncode)
    if time.monotonic() >= deadline:
        break
"""
    perf_command = [perf, "record", "-F", "99", "-e", "task-clock", "-g",
                    "--call-graph", "dwarf", "-o", str(profile), "--",
                    sys.executable, "-c", repeat_driver, *command]
    with stdout.open("wb") as output:
        result = runner.run_process(perf_command, cwd=run_dir, env=env,
                                    stdout=output, stderr=subprocess.STDOUT,
                                    timeout=runner.COMMAND_TIMEOUT_SECONDS)
    if result.returncode:
        raise RuntimeError(f"{name}: perf/vvp exit {result.returncode}; "
                           f"{stdout.read_text(errors='replace')[-3000:]}")

    report_path = reports / f"{name}.txt"
    report_command = [perf, "report", "--stdio", "--no-children", "-g",
                      "-i", str(profile)]
    with report_path.open("w", encoding="utf-8") as report:
        report_result = runner.run_process(report_command, env=env, stdout=report,
                                           stderr=subprocess.STDOUT, timeout=60)
    if report_result.returncode:
        raise RuntimeError(f"perf report failed for {name}: {report_path}")

    output_hash, artifacts = runner.hash_outputs(run_dir)
    compressed = profile.with_suffix(".data.gz")
    with profile.open("rb") as raw, gzip.open(compressed, "wb", compresslevel=1) as zipped:
        shutil.copyfileobj(raw, zipped)
    profile.unlink()
    summary["benchmarks"][name] = {
        "wall_seconds": round(time.monotonic() - started, 3),
        "return_code": result.returncode,
        "output_sha256": output_hash,
        "artifacts": artifacts,
        "profile_gzip": compressed.name,
        "report": report_path.name,
    }
    print(f"{name}\t{summary['benchmarks'][name]['wall_seconds']}\t{output_hash}", flush=True)

(root / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
