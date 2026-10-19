#!/usr/bin/env python3
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys

source = Path(sys.argv[1]).resolve()
root = Path(sys.argv[2]).resolve()
runner_path = source / "benchmarks/sim-hotspots/run_json.py"
spec = importlib.util.spec_from_file_location("sim_hotspots_json", runner_path)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
compiler = runner.command_words("IVERILOG", "iverilog")
runtime = os.environ["VVP_BIN"]
build = root / "build"
build.mkdir(parents=True, exist_ok=True)
plugin_dir = runner.build_vpi_module(build)
cpu = runner.pin_one_cpu()
if not cpu:
    raise SystemExit("could not pin the counter screen to one CPU")
env = os.environ.copy()
env["IVL_PERF_STATS"] = "1"
env["LC_ALL"] = "C"
summary = {"source": str(source), "cpu_affinity": cpu, "benchmarks": {}}

for name in runner.BENCHMARKS:
    program = runner.compile_bench(name, build, compiler)
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

    stdout = run_dir / "stdout.bin"
    stderr = run_dir / "stderr.log"
    with stdout.open("wb") as out, stderr.open("wb") as err:
        result = runner.run_process(command, cwd=run_dir, env=env,
                                    stdout=out, stderr=err,
                                    timeout=runner.COMMAND_TIMEOUT_SECONDS)
    if result.returncode:
        raise RuntimeError(f"{name}: vvp exit {result.returncode}")
    lines = [line for line in stderr.read_text(errors="replace").splitlines()
             if line.startswith("VVP_PERF_STATS ")]
    if len(lines) != 1:
        raise RuntimeError(f"{name}: expected one stats line, got {len(lines)}")
    stats = json.loads(lines[0][len("VVP_PERF_STATS "):])
    queue = stats["scheduler_time_list"]
    insertions = queue["insertions"]
    summary["benchmarks"][name] = {
        "scheduler_time_list": {
            **queue,
            "average_steps": (queue["total_steps"] / insertions
                              if insertions else 0),
        },
        "thread_wakes": stats["thread_wakes"],
        "stdout_sha256": hashlib.sha256(stdout.read_bytes()).hexdigest(),
    }
    print(f"{name}\t{insertions}\t{queue['total_steps']}\t{queue['max_steps']}",
          flush=True)

(root / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
with (root / "scheduler-time-list.csv").open("w") as out:
    out.write("benchmark,insertions,total_steps,max_steps,average_steps\n")
    for name, result in summary["benchmarks"].items():
        q = result["scheduler_time_list"]
        out.write(f"{name},{q['insertions']},{q['total_steps']},{q['max_steps']},{q['average_steps']:.6f}\n")
