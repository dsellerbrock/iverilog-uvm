#!/usr/bin/env python3
"""Interleaved, byte-strict measurements for the simulation hot-spot corpus."""

import csv
import hashlib
import json
import os
import platform
import re
import signal
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
COMMAND_TIMEOUT_SECONDS = 1200
TERMINATE_GRACE_SECONDS = 5
LARGE_MEMORY_WORDS = 16384
BENCHMARKS = (
    "rtl_pipe",
    "rtl_alu",
    "behav",
    "classq",
    "uvm_traffic",
    "randomize_z3",
    "randomize_dv_txn",
    "wide_vectors",
    "gate_strength",
    "multi_clock",
    "large_memory",
    "io_text",
    "waveform_vcd",
    "waveform_fst",
    "vpi_callbacks",
    "strings_aa_queue",
    "uvm_config_factory",
    "fork_heavy",
)
SOURCES = {
    "waveform_vcd": "waveform.sv",
    "waveform_fst": "waveform.sv",
}
UVM_BENCHMARKS = {"uvm_traffic", "uvm_config_factory"}


def file_sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def output_files(root):
    files = {}
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(root)
        if relative.parts and relative.parts[0] == ".inputs":
            continue
        files[relative.as_posix()] = file_sha256(path)
    return files


def stage_inputs(name, input_dir):
    if name == "large_memory":
        (input_dir / "large_memory.hex").write_text(
            "".join(f"{word:08x}\n" for word in range(LARGE_MEMORY_WORDS)),
            encoding="ascii",
        )


def hash_outputs(root):
    """Hash stdout and generated files, excluding copied benchmark inputs."""
    files = output_files(Path(root))
    digest = hashlib.sha256()
    for name, content_hash in files.items():
        name_bytes = name.encode("utf-8")
        digest.update(len(name_bytes).to_bytes(8, "big"))
        digest.update(name_bytes)
        digest.update(bytes.fromhex(content_hash))
    return digest.hexdigest(), files


def compare_outputs(left, right):
    left_root = Path(left)
    right_root = Path(right)
    left_files = output_files(left_root)
    right_files = output_files(right_root)
    if left_files != right_files:
        return False
    return all(
        (left_root / name).read_bytes() == (right_root / name).read_bytes()
        for name in left_files
    )


def parse_perf_stat(text):
    parsed = {"instructions": None, "task_clock_ms": None}
    for row in csv.reader(text.splitlines()):
        if len(row) < 3:
            continue
        raw_value = row[0].strip()
        event = row[2].strip().split(":", 1)[0]
        try:
            value = float(raw_value)
        except ValueError:
            continue
        if event == "instructions":
            parsed["instructions"] = int(value)
        elif event == "task-clock":
            parsed["task_clock_ms"] = value
    return parsed


def summarize_samples(values):
    values = [float(value) for value in values if value is not None]
    if not values:
        return {"median": None, "min": None, "max": None, "spread_pct": None}
    median = statistics.median(values)
    spread = None if median == 0 else (max(values) - min(values)) / median * 100.0
    return {
        "median": median,
        "min": min(values),
        "max": max(values),
        "spread_pct": spread,
    }


def run_process(command, timeout=COMMAND_TIMEOUT_SECONDS, **kwargs):
    process = subprocess.Popen(command, start_new_session=True, **kwargs)
    try:
        stdout, stderr = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            stdout, stderr = process.communicate(timeout=TERMINATE_GRACE_SECONDS)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            stdout, stderr = process.communicate()
        raise TimeoutError(f"command timed out after {timeout}s: {command[0]}")
    return subprocess.CompletedProcess(command, process.returncode, stdout, stderr)


def pin_one_cpu():
    if not hasattr(os, "sched_getaffinity") or not hasattr(os, "sched_setaffinity"):
        return None
    allowed = sorted(os.sched_getaffinity(0))
    if not allowed:
        return []
    selected = allowed[0]
    os.sched_setaffinity(0, {selected})
    return [selected]


def command_words(variable, default):
    value = os.environ.get(variable)
    if value:
        return value.split()
    found = shutil.which(default)
    return [found] if found else []


def perf_command():
    return None


def parse_rss(time_path):
    if not time_path.exists():
        return None
    text = time_path.read_text(errors="replace")
    if platform.system() == "Linux":
        try:
            return int(text.strip().splitlines()[-1]) * 1024
        except (ValueError, IndexError):
            return None
    match = re.search(r"([0-9]+)\s+maximum resident set size", text)
    return int(match.group(1)) if match else None


def time_wrapped(command, time_path):
    time_bin = Path("/usr/bin/time")
    if not time_bin.exists():
        return command
    if platform.system() == "Linux":
        return [str(time_bin), "-f", "%M", "-o", str(time_path), "--", *command]
    if platform.system() == "Darwin":
        return [str(time_bin), "-l", "-o", str(time_path), *command]
    return command


def measurement_command(command, time_path, perf, perf_path):
    command = time_wrapped(command, time_path)
    if perf:
        command = [perf, "stat", "-x,", "--no-big-num", "-e", "instructions,task-clock",
                   "-o", str(perf_path), "--", *command]
    return command


def compile_bench(name, work_root, compiler, side):
    output = work_root / f"{name}-{side}.vvp"
    source = HERE / SOURCES.get(name, f"{name}.sv")
    if not source.is_file():
        raise RuntimeError(f"missing benchmark source: {source.name}")
    command = [*compiler]
    if name in UVM_BENCHMARKS:
        uvm = ROOT / "uvm-core" / "src"
        command.extend(["-g2012", "-I", str(uvm), "-o", str(output),
                        str(uvm / "uvm_pkg.sv"), str(source)])
    elif name.startswith("randomize_"):
        command.extend(["-g2017", "-s", "main", "-o", str(output), str(source)])
    else:
        command.extend(["-g2012", "-o", str(output), str(source)])
    log = work_root / f"{name}-{side}.compile.log"
    with log.open("wb") as stream:
        result = run_process(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT,
                             timeout=120)
    if result.returncode:
        raise RuntimeError(f"compile failed for {name}: {log.read_text(errors='replace')}")
    return output


def build_vpi_module(work_root):
    compiler = command_words("IVERILOG_VPI", "iverilog-vpi")
    if not compiler:
        raise RuntimeError("iverilog-vpi is required for the VPI callback workload")
    plugin_dir = work_root / "vpi"
    plugin_dir.mkdir()
    source = HERE / "vpi_callbacks.c"
    result = run_process(
        [*compiler, "--name=vpi_callbacks", str(source)],
        cwd=plugin_dir,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        timeout=60,
    )
    plugin = plugin_dir / "vpi_callbacks.vpi"
    if result.returncode or not plugin.exists():
        raise RuntimeError(f"VPI module build failed: {result.stdout}")
    return plugin_dir


def runtime_arguments(name, runtime, plugin_dir):
    command = [runtime, "-n"]
    if name in UVM_BENCHMARKS:
        dpi = os.environ.get("UVM_DPI", str(ROOT / "local-install/lib/ivl/uvm_dpi.vpi"))
        if not Path(dpi).is_file():
            raise RuntimeError(f"UVM DPI module not found: {dpi} (set UVM_DPI)")
        command.extend(["-d", dpi])
    if name == "vpi_callbacks":
        command.extend(["-M", str(plugin_dir), "-m", "vpi_callbacks"])
    return command


def measure(runtime_command, program, name, run_dir, metadata_dir, label, perf):
    run_dir.mkdir(parents=True)
    input_dir = run_dir / ".inputs"
    input_dir.mkdir()
    stage_inputs(name, input_dir)

    output_path = run_dir / "stdout.bin"
    time_path = metadata_dir / f"{label}.time"
    perf_path = metadata_dir / f"{label}.perf.csv"
    command = [*runtime_command, str(program)]
    if name == "randomize_dv_txn":
        command.append("+runs=400")
    if name == "waveform_fst":
        command.extend(["+use_fst", "-fst", "-no-date"])
    elif name == "waveform_vcd":
        command.extend(["+use_vcd", "-vcd", "-no-date"])
    command = measurement_command(command, time_path, perf, perf_path)
    env = os.environ.copy()
    env["LC_ALL"] = "C"
    start = time.perf_counter()
    with output_path.open("wb") as stream:
        result = run_process(command, cwd=run_dir, env=env, stdout=stream,
                             stderr=subprocess.STDOUT)
    wall = time.perf_counter() - start
    if result.returncode:
        raise RuntimeError(
            f"{label} exited {result.returncode}; output: "
            f"{output_path.read_text(errors='replace')[-4000:]}"
        )
    perf_stats = {"instructions": None, "task_clock_ms": None}
    if perf and perf_path.exists():
        perf_stats = parse_perf_stat(perf_path.read_text(errors="replace"))
    output_hash, artifacts = hash_outputs(run_dir)
    return {
        "wall_seconds": wall,
        "instructions": perf_stats["instructions"],
        "task_clock_ms": perf_stats["task_clock_ms"],
        "max_rss_bytes": parse_rss(time_path),
        "output_sha256": output_hash,
        "artifacts": artifacts,
        "return_code": result.returncode,
        "_output_dir": str(run_dir),
    }


def summarize_measurements(samples, key):
    values = [sample[key] for sample in samples]
    summary = summarize_samples(values)
    if key == "max_rss_bytes":
        available = [value for value in values if value is not None]
        if available:
            summary["max"] = max(available)
    return summary


def run_benchmark(name, reference, candidate, runs, work_root,
                  reference_compiler, candidate_compiler, perf, plugin_dir):
    reference_program = compile_bench(name, work_root, reference_compiler, "reference")
    candidate_program = compile_bench(name, work_root, candidate_compiler, "candidate")
    ref_cmd = runtime_arguments(name, reference, plugin_dir)
    new_cmd = runtime_arguments(name, candidate, plugin_dir)
    samples = []
    ref_metrics = []
    new_metrics = []
    all_equal = True
    for index in range(runs):
        order = ("reference", "candidate") if index % 2 == 0 else ("candidate", "reference")
        sample = {"run": index + 1, "order": list(order)}
        outputs = {}
        for label in order:
            binary = reference if label == "reference" else candidate
            runtime_cmd = ref_cmd if label == "reference" else new_cmd
            program = reference_program if label == "reference" else candidate_program
            directory = work_root / "runs" / name / f"{index + 1:02d}-{label}"
            metrics = measure(runtime_cmd, program, name, directory, work_root,
                              f"{name}-{index + 1:02d}-{label}", perf)
            outputs[label] = metrics
            (ref_metrics if label == "reference" else new_metrics).append(metrics)
        identical = compare_outputs(outputs["reference"]["_output_dir"],
                                    outputs["candidate"]["_output_dir"])
        sample["identical"] = identical
        for label in ("reference", "candidate"):
            outputs[label].pop("_output_dir")
        sample.update(outputs)
        samples.append(sample)
        all_equal = all_equal and identical

    ref_summary = {key: summarize_measurements(ref_metrics, key)
                   for key in ("wall_seconds", "instructions", "task_clock_ms", "max_rss_bytes")}
    new_summary = {key: summarize_measurements(new_metrics, key)
                   for key in ("wall_seconds", "instructions", "task_clock_ms", "max_rss_bytes")}
    ref_median = ref_summary["wall_seconds"]["median"]
    new_median = new_summary["wall_seconds"]["median"]
    return {
        "status": "ok" if all_equal else "output_mismatch",
        "identical_all_runs": all_equal,
        "summary": {
            "reference": ref_summary,
            "candidate": new_summary,
            "speedup": ref_median / new_median if ref_median and new_median else None,
        },
        "samples": samples,
    }


def main(argv):
    if len(argv) < 2 or len(argv) > 3:
        print("usage: run.sh --json <reference-vvp> <candidate-vvp> [runs]", file=sys.stderr)
        return 2
    reference = str(Path(argv[0]).resolve())
    candidate = str(Path(argv[1]).resolve())
    runs = int(argv[2]) if len(argv) == 3 else 5
    if runs < 1:
        print("runs must be positive", file=sys.stderr)
        return 2
    for runtime in (reference, candidate):
        if not Path(runtime).is_file() or not os.access(runtime, os.X_OK):
            print(f"runtime is not executable: {runtime}", file=sys.stderr)
            return 2

    reference_compiler = command_words("REFERENCE_IVERILOG", "iverilog")
    candidate_compiler = command_words("IVERILOG", "iverilog")
    if not reference_compiler or not candidate_compiler:
        print("both compilers are required (set REFERENCE_IVERILOG and IVERILOG)",
              file=sys.stderr)
        return 2
    affinity = pin_one_cpu()
    perf = perf_command()
    result = {
        "schema_version": 1,
        "runs": runs,
        "reference_vvp": reference,
        "candidate_vvp": candidate,
        "reference_iverilog": reference_compiler,
        "candidate_iverilog": candidate_compiler,
        "cpu_affinity": affinity,
        "perf_stat_available": perf is not None,
        "benchmarks": {},
    }
    status = 0
    with tempfile.TemporaryDirectory(prefix="sim-hotspots-json-") as temp:
        work_root = Path(temp)
        plugin_dir = None
        try:
            plugin_dir = build_vpi_module(work_root)
        except Exception as error:
            result["benchmarks"]["vpi_callbacks"] = {"status": "error", "error": str(error)}
            status = 1
        for name in BENCHMARKS:
            if name == "vpi_callbacks" and plugin_dir is None:
                continue
            try:
                item = run_benchmark(name, reference, candidate, runs, work_root,
                                     reference_compiler, candidate_compiler,
                                     perf, plugin_dir)
                result["benchmarks"][name] = item
                if not item["identical_all_runs"]:
                    status = 1
            except Exception as error:
                result["benchmarks"][name] = {"status": "error", "error": str(error)}
                status = 1
    json.dump(result, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return status


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except BrokenPipeError:
        sys.exit(1)
