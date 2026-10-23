#!/usr/bin/env python3
"""Collect opt-in T0..T4 counts for the small randomization corpus."""

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

source, install, output = map(lambda value: Path(value).resolve(), sys.argv[1:])
bench_dir = source / "benchmarks/sim-hotspots"
sys.path.insert(0, str(bench_dir))
import run_json

output.mkdir(parents=True, exist_ok=True)
os.environ["IVERILOG"] = str(install / "bin/iverilog")
os.environ["IVERILOG_VPI"] = str(install / "bin/iverilog-vpi")
os.environ["UVM_DPI"] = str(install / "lib/ivl/uvm_dpi.vpi")
compiler = run_json.command_words("IVERILOG", "iverilog")
runtime = str(install / "bin/vvp")
os.environ["LC_ALL"] = "C"


def collect(name, program, run_root, arguments=()):
    run_dir = run_root / name
    run_dir.mkdir()
    env = os.environ.copy()
    env["IVL_PERF_STATS"] = "1"
    command = [*run_json.runtime_arguments(name, runtime, None),
               str(program), *arguments]
    result = run_json.run_process(command, cwd=run_dir, env=env,
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                  timeout=180)
    if result.returncode:
        raise RuntimeError(f"{name} failed: {result.stderr.decode(errors='replace')[-2000:]}")
    combined = result.stdout + result.stderr
    matches = re.findall(rb"^VVP_PERF_STATS (\{.*\})$", combined, re.MULTILINE)
    if len(matches) != 1:
        raise RuntimeError(f"{name}: expected one VVP_PERF_STATS record")
    report = json.loads(matches[0])
    return {
        "tiers": report["randomize_tiers"],
        "z3": report["z3"],
        "stdout_sha256": hashlib.sha256(result.stdout).hexdigest(),
        "stderr_sha256": hashlib.sha256(result.stderr).hexdigest(),
    }


results = {}
with tempfile.TemporaryDirectory(prefix="wp7-tier-hist-") as temporary:
    temp_root = Path(temporary)
    work = temp_root / "work"
    work.mkdir()
    run_root = temp_root / "runs"
    run_root.mkdir()
    for name in ("randomize_z3", "randomize_dv_txn", "uvm_traffic"):
        program = run_json.compile_bench(name, work, compiler)
        args = ["+runs=400"] if name == "randomize_dv_txn" else []
        results[name] = collect(name, program, run_root, args)

    fixture = bench_dir / "randomize_t0_disabled.sv"
    program = work / "randomize_t0_disabled.vvp"
    compiled = run_json.run_process(
        [*compiler, "-g2017", "-s", "main", "-o", str(program), str(fixture)],
        cwd=source, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
    if compiled.returncode:
        raise RuntimeError(compiled.stdout.decode(errors="replace")[-4000:])
    results["randomize_t0_disabled"] = collect("randomize_t0_disabled", program, run_root)
    results["randomize_t4_soft"] = collect("randomize_t4_soft", program, run_root, ["+t4"])
(output / "histogram.json").write_text(json.dumps(results, indent=2, sort_keys=True) + "\n")
print(json.dumps(results, indent=2, sort_keys=True))
