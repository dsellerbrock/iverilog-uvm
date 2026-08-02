#!/usr/bin/env python3
"""Run a reproducible Icarus Verilog conformance matrix over OpenTitan cores.

The matrix deliberately distinguishes a clean compile from a successful process
exit that emitted semantic-degradation warnings.  Its output is intended to be
both a gap census and a durable record of exactly which OpenTitan revision,
compiler, provider mappings, and commands produced each result.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import dataclasses
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import time
from typing import Iterable, Sequence


LANES = ("rtl", "sva", "uvm", "runtime")
TARGETS = {"rtl": "default", "sva": "formal", "uvm": "sim", "runtime": "sim"}
DEFAULT_TOPS = {
    "earlgrey": "lowrisc:systems:top_earlgrey:0.1",
    "darjeeling": "lowrisc:systems:top_darjeeling:0.1",
}
PRIM_MAPPING = "lowrisc:prim_generic:all:0.1"

CORE_LINE_RE = re.compile(r"^(?P<core>[^\s:]+:[^\s:]+:[^\s:]+:[^\s]+)\s+:\s+")
MAKE_ASSIGN_RE = re.compile(r"^(?P<name>[A-Z_]+)\s*:?=\s*(?P<value>.*)$")
HARD_ERROR_PATTERNS = (
    re.compile(r"\bsyntax error\b", re.I),
    re.compile(r"(?:^|\s)(?:error|sorry):", re.I),
    re.compile(r"\binternal error\b", re.I),
    re.compile(r"\bsegmentation fault\b", re.I),
    re.compile(r"\bassertion (?:failed|failure)\b", re.I),
    re.compile(r"\bcore dumped\b", re.I),
)
DEBT_PATTERNS = (
    re.compile(r"\bwarning:", re.I),
    re.compile(r"compile-progress", re.I),
    re.compile(r"\b(?:ignored|dropp(?:ed|ing))\b", re.I),
    re.compile(r"\b(?:degraded|fallback|approximat(?:e|ed|ion|ing))\b", re.I),
    re.compile(r"\bnot yet (?:supported|implemented)\b", re.I),
    re.compile(r"\b(?:did not|unable to) (?:resolve|bind)\b", re.I),
    re.compile(r"\bunknown (?:task|function|method)\b", re.I),
    re.compile(r"nonblocking .* blocking", re.I),
)
SETUP_ALLOWLIST = (
    re.compile(r"No trustfile configured .* signatures will not be checked", re.I),
    # This is an Edalize API-lifecycle notice.  It does not change the selected
    # sources, provider mapping, compiler invocation, or HDL semantics.
    re.compile(r"This backend is deprecated .* migrate to the flow API", re.I),
)
NO_TOPLEVEL_RE = re.compile(r"Target '[^']+' has no toplevel", re.I)


@dataclasses.dataclass(frozen=True)
class Core:
    vlnv: str
    description: str

    @property
    def library(self) -> str:
        return self.vlnv.split(":", 3)[1]

    @property
    def name(self) -> str:
        return self.vlnv.split(":", 3)[2]


@dataclasses.dataclass(frozen=True)
class Job:
    lane: str
    core: Core

    @property
    def target(self) -> str:
        return TARGETS[self.lane]


@dataclasses.dataclass
class CommandResult:
    command: list[str]
    returncode: int
    output: str
    duration_seconds: float
    timed_out: bool = False


def command_result(
    command: Sequence[str],
    *,
    cwd: Path,
    env: dict[str, str],
    timeout: int,
) -> CommandResult:
    started = time.monotonic()
    try:
        completed = subprocess.run(
            list(command),
            cwd=cwd,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=timeout,
            check=False,
        )
        return CommandResult(
            list(command),
            completed.returncode,
            completed.stdout,
            time.monotonic() - started,
        )
    except subprocess.TimeoutExpired as exc:
        output = exc.stdout or ""
        if isinstance(output, bytes):
            output = output.decode(errors="replace")
        return CommandResult(
            list(command), 124, output, time.monotonic() - started, True
        )


def short_command(command: Sequence[str]) -> str:
    return shlex.join(str(part) for part in command)


def git_value(root: Path, *args: str) -> str:
    completed = subprocess.run(
        ["git", *args],
        cwd=root,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )
    return completed.stdout.strip() if completed.returncode == 0 else "unknown"


def tool_version(command: Sequence[str], cwd: Path, env: dict[str, str]) -> str:
    result = command_result(command, cwd=cwd, env=env, timeout=30)
    lines = [line.strip() for line in result.output.splitlines() if line.strip()]
    return lines[0] if lines else "unknown"


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def discover_cores(
    fusesoc: Path, opentitan_root: Path, env: dict[str, str], timeout: int
) -> list[Core]:
    result = command_result(
        [str(fusesoc), f"--cores-root={opentitan_root}", "core", "list"],
        cwd=opentitan_root,
        env=env,
        timeout=timeout,
    )
    if result.returncode != 0:
        raise RuntimeError(
            "FuseSoC core discovery failed:\n" + result.output.rstrip()
        )

    cores: list[Core] = []
    for line in result.output.splitlines():
        match = CORE_LINE_RE.match(line)
        if not match:
            continue
        fields = [field.strip() for field in line.split(" : ")]
        description = fields[-1] if len(fields) >= 4 else ""
        cores.append(Core(match.group("core"), description))
    if not cores:
        raise RuntimeError("FuseSoC returned no parseable OpenTitan cores")
    return cores


def core_supports_lane(core: Core, lane: str) -> bool:
    dv_library = core.library == "dv" or core.library.endswith("_dv")
    fpv_core = core.name.endswith("_fpv")
    if lane in ("uvm", "runtime"):
        return dv_library and core.name.endswith("_sim")
    if lane == "sva":
        return (dv_library and core.name.endswith("_sva")) or fpv_core
    if lane == "rtl":
        return (
            not fpv_core
            and (
                core.library in {"ip", "prim", "tlul", "ibex", "systems"}
                or core.library.endswith("_ip")
            )
        )
    raise ValueError(f"unknown lane: {lane}")


def requested_lanes(values: Sequence[str]) -> list[str]:
    if not values or "all" in values:
        return list(LANES)
    return [lane for lane in LANES if lane in values]


def select_jobs(cores: Iterable[Core], args: argparse.Namespace) -> list[Job]:
    lanes = requested_lanes(args.lane)
    exact_cores = set(args.core)
    filters = [value.casefold() for value in args.ip]
    jobs: list[Job] = []
    for lane in lanes:
        for core in cores:
            if exact_cores and core.vlnv not in exact_cores:
                continue
            haystack = f"{core.vlnv} {core.description}".casefold()
            if filters and not any(value in haystack for value in filters):
                continue
            if core_supports_lane(core, lane):
                jobs.append(Job(lane, core))
    jobs.sort(key=lambda job: (LANES.index(job.lane), job.core.vlnv))
    if args.max_cores:
        jobs = jobs[: args.max_cores]
    return jobs


def safe_name(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", value).strip("_")


def top_for_job(job: Job, requested: str) -> str:
    if requested != "auto":
        return requested
    return "darjeeling" if "darjeeling" in job.core.vlnv else "earlgrey"


def provider_mappings(job: Job, requested_top: str) -> list[str]:
    top = top_for_job(job, requested_top)
    return [PRIM_MAPPING, DEFAULT_TOPS[top]]


def actionable_setup_lines(output: str) -> list[str]:
    findings: list[str] = []
    for line in output.splitlines():
        if "warning" not in line.casefold():
            continue
        if any(pattern.search(line) for pattern in SETUP_ALLOWLIST):
            continue
        findings.append(line.strip())
    return findings


def matching_lines(output: str, patterns: Sequence[re.Pattern[str]]) -> list[str]:
    findings: list[str] = []
    seen: set[str] = set()
    for line in output.splitlines():
        if any(pattern.search(line) for pattern in patterns):
            normalized = line.strip()
            if normalized and normalized not in seen:
                findings.append(normalized)
                seen.add(normalized)
    return findings


def parse_makefile(work_root: Path) -> tuple[Path, list[str]]:
    makefiles = sorted(work_root.rglob("Makefile"), key=lambda path: len(path.parts))
    for makefile in makefiles:
        assignments: dict[str, str] = {}
        for line in makefile.read_text(errors="replace").splitlines():
            match = MAKE_ASSIGN_RE.match(line)
            if match:
                assignments[match.group("name")] = match.group("value").strip()
        target = assignments.get("TARGET")
        if not target:
            continue
        source_list = makefile.parent / f"{target}.scr"
        if source_list.is_file():
            return source_list, shlex.split(assignments.get("TOPLEVEL", ""))
    raise FileNotFoundError(f"no generated Icarus Makefile/source list below {work_root}")


def setup_command(
    job: Job,
    fusesoc: Path,
    opentitan_root: Path,
    work_root: Path,
    requested_top: str,
) -> list[str]:
    command = [
        str(fusesoc),
        f"--cores-root={opentitan_root}",
        "run",
        f"--target={job.target}",
        "--tool=icarus",
        "--setup",
        f"--work-root={work_root}",
    ]
    for mapping in provider_mappings(job, requested_top):
        command.append(f"--mapping={mapping}")
    command.append(job.core.vlnv)
    return command


def compile_command(
    job: Job,
    iverilog: Path,
    source_list: Path,
    top_options: Sequence[str],
    output: Path,
) -> list[str]:
    command = [str(iverilog), "-g2012", *top_options]
    if job.lane == "rtl":
        command.extend(["-S", "-DSYNTHESIS"])
    elif job.lane == "sva":
        # OpenTitan SVA cores deliberately depend on DV interfaces that include
        # and import UVM.  Supplying the package is therefore part of compiling
        # the unmodified formal fileset, even though this lane does not run DPI.
        command.extend(
            ["-gassertions", "-DASSERT_ON", "-uvm", "--uvm-no-dpi", "-DUVM"]
        )
    else:
        command.extend(
            [
                "-uvm",
                "-DUVM",
                "-DUVM_NO_DEPRECATED",
                "-DUVM_REG_ADDR_WIDTH=32",
                "-DUVM_REG_DATA_WIDTH=32",
                "-DUVM_REG_BYTENABLE_WIDTH=4",
                "-DSIMULATION",
                "-DDUT_HIER=tb.dut",
            ]
        )
    command.extend(["-o", str(output), "-c", str(source_list)])
    return command


def result_base(job: Job, work_root: Path, mappings: list[str]) -> dict[str, object]:
    return {
        "lane": job.lane,
        "core": job.core.vlnv,
        "description": job.core.description,
        "target": job.target,
        "work_root": str(work_root),
        "provider_mappings": mappings,
        "status": "NOT_RUN",
        "security_vulnerability": False,
    }


def write_log(path: Path, heading: str, result: CommandResult) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        f"{heading}\ncommand: {short_command(result.command)}\n"
        f"returncode: {result.returncode}\n"
        f"duration_seconds: {result.duration_seconds:.3f}\n\n{result.output}"
    )


def run_job(
    job: Job,
    *,
    args: argparse.Namespace,
    opentitan_root: Path,
    build_root: Path,
    fusesoc: Path,
    iverilog: Path,
    vvp: Path,
    env: dict[str, str],
) -> dict[str, object]:
    work_root = build_root / job.lane / safe_name(job.core.vlnv)
    work_root.mkdir(parents=True, exist_ok=True)
    mappings = provider_mappings(job, args.top)
    record = result_base(job, work_root, mappings)

    setup = command_result(
        setup_command(job, fusesoc, opentitan_root, work_root, args.top),
        cwd=opentitan_root,
        env=env,
        timeout=args.setup_timeout,
    )
    setup_log = work_root / "matrix-setup.log"
    write_log(setup_log, "OpenTitan FuseSoC setup", setup)
    setup_findings = actionable_setup_lines(setup.output)
    record.update(
        {
            "setup_command": short_command(setup.command),
            "setup_returncode": setup.returncode,
            "setup_duration_seconds": round(setup.duration_seconds, 3),
            "setup_timed_out": setup.timed_out,
            "setup_log": str(setup_log),
            "setup_warnings": setup_findings,
        }
    )
    if setup.timed_out:
        record["status"] = "SETUP_TIMEOUT"
        return record
    if setup.returncode != 0:
        if NO_TOPLEVEL_RE.search(setup.output):
            # CAPI package/fileset cores are dependencies, not standalone
            # elaboration units.  They are compiled through every runnable
            # parent that depends on them and must not become false failures.
            record.update(
                {
                    "status": "DEPENDENCY_ONLY",
                    "coverage_mode": "compiled_through_parent_toplevel",
                }
            )
            return record
        record["status"] = "SETUP_FAIL"
        return record
    if args.setup_only:
        record["status"] = "SETUP_DEBT" if setup_findings else "SETUP_ONLY"
        return record

    try:
        source_list, top_options = parse_makefile(work_root)
    except (FileNotFoundError, OSError, ValueError) as exc:
        record.update({"status": "SETUP_FAIL", "matrix_error": str(exc)})
        return record

    executable = work_root / f"matrix-{job.lane}.vvp"
    compile_result = command_result(
        compile_command(job, iverilog, source_list, top_options, executable),
        cwd=source_list.parent,
        env=env,
        timeout=args.compile_timeout,
    )
    compile_log = work_root / "matrix-compile.log"
    write_log(compile_log, "OpenTitan Icarus compile", compile_result)
    hard_errors = matching_lines(compile_result.output, HARD_ERROR_PATTERNS)
    semantic_debt = matching_lines(compile_result.output, DEBT_PATTERNS)
    record.update(
        {
            "source_list": str(source_list),
            "top_options": top_options,
            "compile_command": short_command(compile_result.command),
            "compile_returncode": compile_result.returncode,
            "compile_duration_seconds": round(compile_result.duration_seconds, 3),
            "compile_timed_out": compile_result.timed_out,
            "compile_log": str(compile_log),
            "hard_error_count": len(hard_errors),
            "hard_errors": hard_errors[: args.diagnostic_limit],
            "semantic_debt_count": len(semantic_debt),
            "semantic_debt": semantic_debt[: args.diagnostic_limit],
            "output_sha256": hashlib.sha256(
                compile_result.output.encode(errors="replace")
            ).hexdigest(),
        }
    )
    if compile_result.timed_out:
        record["status"] = "COMPILE_TIMEOUT"
        return record
    if compile_result.returncode != 0 or hard_errors:
        record["status"] = "FAIL"
        return record
    if setup_findings or semantic_debt:
        record["status"] = "DEBT"
    else:
        record["status"] = "PASS"

    if job.lane != "runtime":
        return record

    runtime_command = [str(vvp), "-n", str(executable), *args.runtime_arg]
    runtime_result = command_result(
        runtime_command,
        cwd=source_list.parent,
        env={**env, "IVL_SVA_NFA": "1"},
        timeout=args.runtime_timeout,
    )
    runtime_log = work_root / "matrix-runtime.log"
    write_log(runtime_log, "OpenTitan UVM runtime", runtime_result)
    runtime_errors = matching_lines(runtime_result.output, HARD_ERROR_PATTERNS)
    runtime_debt = matching_lines(runtime_result.output, DEBT_PATTERNS)
    record.update(
        {
            "runtime_command": short_command(runtime_command),
            "runtime_returncode": runtime_result.returncode,
            "runtime_duration_seconds": round(runtime_result.duration_seconds, 3),
            "runtime_timed_out": runtime_result.timed_out,
            "runtime_log": str(runtime_log),
            "runtime_error_count": len(runtime_errors),
            "runtime_errors": runtime_errors[: args.diagnostic_limit],
            "runtime_debt_count": len(runtime_debt),
            "runtime_debt": runtime_debt[: args.diagnostic_limit],
        }
    )
    if runtime_result.timed_out:
        record["status"] = "RUNTIME_TIMEOUT"
    elif runtime_result.returncode != 0 or runtime_errors:
        record["status"] = "RUNTIME_FAIL"
    elif setup_findings or semantic_debt or runtime_debt:
        record["status"] = "DEBT"
    else:
        record["status"] = "PASS"
    return record


def markdown_report(report: dict[str, object]) -> str:
    metadata = report["metadata"]
    results = report["results"]
    counts: dict[str, int] = {}
    for result in results:
        status = str(result["status"])
        counts[status] = counts.get(status, 0) + 1

    lines = [
        "# OpenTitan Icarus matrix",
        "",
        f"- Generated: `{metadata['generated_at']}`",
        f"- OpenTitan revision: `{metadata['opentitan_revision']}`"
        + (" (dirty)" if metadata["opentitan_dirty"] else ""),
        f"- Icarus: `{metadata['iverilog_version']}`",
        f"- Jobs: `{len(results)}`",
        "- Status counts: "
        + ", ".join(f"`{key}={value}`" for key, value in sorted(counts.items())),
        "",
        "A `DEBT` result exited successfully but emitted a warning or explicit semantic "
        "degradation. It is not a conformance pass.",
        "",
        "| Lane | Core | Status | Hard errors | Semantic debt | Log |",
        "|---|---|---:|---:|---:|---|",
    ]
    for result in results:
        log_path = result.get("runtime_log") or result.get("compile_log") or result.get("setup_log")
        lines.append(
            "| {lane} | `{core}` | **{status}** | {hard} | {debt} | `{log}` |".format(
                lane=result["lane"],
                core=result["core"],
                status=result["status"],
                hard=result.get("hard_error_count", result.get("runtime_error_count", 0)),
                debt=result.get("semantic_debt_count", 0)
                + result.get("runtime_debt_count", 0),
                log=log_path,
            )
        )
    lines.append("")
    return "\n".join(lines)


def save_report(
    metadata: dict[str, object],
    results: Sequence[dict[str, object]],
    json_path: Path,
    md_path: Path,
) -> None:
    """Atomically checkpoint a report so a long census survives interruption."""
    report: dict[str, object] = {"metadata": metadata, "results": list(results)}
    json_path.parent.mkdir(parents=True, exist_ok=True)
    md_path.parent.mkdir(parents=True, exist_ok=True)
    json_temporary = json_path.with_name(json_path.name + ".tmp")
    md_temporary = md_path.with_name(md_path.name + ".tmp")
    json_temporary.write_text(json.dumps(report, indent=2) + "\n")
    md_temporary.write_text(markdown_report(report))
    json_temporary.replace(json_path)
    md_temporary.replace(md_path)


def print_inventory(jobs: Sequence[Job]) -> None:
    counts = {lane: 0 for lane in LANES}
    for job in jobs:
        counts[job.lane] += 1
    print("OpenTitan matrix candidate inventory")
    print(" ".join(f"{lane}={counts[lane]}" for lane in LANES))
    for job in jobs:
        print(f"{job.lane:7} {job.target:7} {job.core.vlnv}  {job.core.description}")


def self_test() -> None:
    sample = """Available cores:
lowrisc:dv:adc_ctrl_sim:0.1 : local : - : ADC UVM simulation
lowrisc:dv:adc_ctrl_sva:0.1 : local : - : ADC assertions
lowrisc:ip:adc_ctrl:1.0     : local : - : ADC RTL
"""
    parsed = []
    for line in sample.splitlines():
        match = CORE_LINE_RE.match(line)
        if match:
            parsed.append(match.group("core"))
    assert parsed == [
        "lowrisc:dv:adc_ctrl_sim:0.1",
        "lowrisc:dv:adc_ctrl_sva:0.1",
        "lowrisc:ip:adc_ctrl:1.0",
    ]
    assert core_supports_lane(Core(parsed[0], ""), "uvm")
    assert core_supports_lane(Core(parsed[1], ""), "sva")
    assert core_supports_lane(Core(parsed[2], ""), "rtl")
    fpv = Core("lowrisc:darjeeling_ip:rv_plic_fpv:0.1", "")
    assert core_supports_lane(fpv, "sva")
    assert not core_supports_lane(fpv, "rtl")
    assert matching_lines("x: warning: compile-progress fallback", DEBT_PATTERNS)
    assert matching_lines("foo.sv:4: syntax error", HARD_ERROR_PATTERNS)
    assert NO_TOPLEVEL_RE.search("ERROR: x:y:z:0 : Target 'default' has no toplevel")
    assert not actionable_setup_lines(
        "WARNING: No trustfile configured (ssh-trustfile in fusesoc.conf), "
        "signatures will not be checked."
    )
    print("opentitan_matrix self-test: PASS")


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--opentitan-root", type=Path)
    result.add_argument("--build-root", type=Path)
    result.add_argument("--iverilog", type=Path)
    result.add_argument("--fusesoc", type=Path)
    result.add_argument(
        "--lane",
        action="append",
        choices=("all", *LANES),
        default=[],
        help="repeat to select lanes; the default 'all' includes runtime",
    )
    result.add_argument("--core", action="append", default=[], help="exact VLNV")
    result.add_argument("--ip", action="append", default=[], help="name/description substring")
    result.add_argument("--top", choices=("auto", *DEFAULT_TOPS), default="auto")
    result.add_argument("--max-cores", type=int, default=0)
    result.add_argument(
        "--jobs",
        type=int,
        default=1,
        help="number of independent cores to process concurrently",
    )
    result.add_argument("--list", action="store_true")
    result.add_argument("--setup-only", action="store_true")
    result.add_argument("--setup-timeout", type=int, default=600)
    result.add_argument("--compile-timeout", type=int, default=1800)
    result.add_argument("--runtime-timeout", type=int, default=300)
    result.add_argument("--runtime-arg", action="append", default=[])
    result.add_argument("--diagnostic-limit", type=int, default=100)
    result.add_argument("--result-json", type=Path)
    result.add_argument("--result-md", type=Path)
    result.add_argument("--self-test", action="store_true")
    return result


def resolve_executable(value: Path | None, fallback: str) -> Path:
    candidate = str(value) if value else shutil.which(fallback)
    if not candidate:
        raise FileNotFoundError(f"could not find {fallback}; provide --{fallback}")
    resolved = Path(candidate).expanduser().resolve()
    if not resolved.is_file():
        raise FileNotFoundError(f"executable does not exist: {resolved}")
    return resolved


def main(argv: Sequence[str] | None = None) -> int:
    args = parser().parse_args(argv)
    if args.self_test:
        self_test()
        return 0
    if not args.opentitan_root or not args.build_root or not args.iverilog:
        parser().error("--opentitan-root, --build-root, and --iverilog are required")
    if args.jobs < 1:
        parser().error("--jobs must be at least 1")

    opentitan_root = args.opentitan_root.expanduser().resolve()
    build_root = args.build_root.expanduser().resolve()
    iverilog = resolve_executable(args.iverilog, "iverilog")
    fusesoc = resolve_executable(args.fusesoc, "fusesoc")
    vvp_candidate = iverilog.with_name("vvp")
    vvp = vvp_candidate if vvp_candidate.is_file() else resolve_executable(None, "vvp")
    if not opentitan_root.is_dir():
        parser().error(f"OpenTitan root does not exist: {opentitan_root}")
    build_root.mkdir(parents=True, exist_ok=True)

    env = os.environ.copy()
    env["PATH"] = os.pathsep.join(
        [str(iverilog.parent), str(fusesoc.parent), env.get("PATH", "")]
    )
    try:
        cores = discover_cores(fusesoc, opentitan_root, env, args.setup_timeout)
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        return 2
    jobs = select_jobs(cores, args)
    if args.list:
        print_inventory(jobs)
        return 0
    if not jobs:
        print("No OpenTitan cores matched the requested lanes and filters", file=sys.stderr)
        return 2


    metadata: dict[str, object] = {
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "opentitan_root": str(opentitan_root),
        "opentitan_revision": git_value(opentitan_root, "rev-parse", "HEAD"),
        "opentitan_dirty": bool(git_value(opentitan_root, "status", "--porcelain")),
        "iverilog": str(iverilog),
        "iverilog_sha256": file_sha256(iverilog),
        "iverilog_version": tool_version([str(iverilog), "-V"], opentitan_root, env),
        "fusesoc": str(fusesoc),
        "fusesoc_version": tool_version([str(fusesoc), "--version"], opentitan_root, env),
        "top_mapping": args.top,
    }
    json_path = (args.result_json or (build_root / "opentitan-matrix.json")).resolve()
    md_path = (args.result_md or (build_root / "opentitan-matrix.md")).resolve()
    save_report(metadata, [], json_path, md_path)

    def execute(job: Job) -> dict[str, object]:
        return run_job(
            job,
            args=args,
            opentitan_root=opentitan_root,
            build_root=build_root,
            fusesoc=fusesoc,
            iverilog=iverilog,
            vvp=vvp,
            env=env,
        )

    indexed_results: list[tuple[int, dict[str, object]]] = []
    if args.jobs == 1:
        for index, job in enumerate(jobs, 1):
            print(f"[{index}/{len(jobs)}] {job.lane} {job.core.vlnv}", flush=True)
            record = execute(job)
            indexed_results.append((index - 1, record))
            save_report(
                metadata,
                [item for _, item in sorted(indexed_results)],
                json_path,
                md_path,
            )
            print(f"  -> {record['status']}", flush=True)
    else:
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as executor:
            pending = {
                executor.submit(execute, job): (index, job)
                for index, job in enumerate(jobs)
            }
            for completed, future in enumerate(
                concurrent.futures.as_completed(pending), 1
            ):
                index, job = pending[future]
                try:
                    record = future.result()
                except Exception as exc:  # preserve the rest of a long census
                    work_root = build_root / job.lane / safe_name(job.core.vlnv)
                    record = result_base(
                        job, work_root, provider_mappings(job, args.top)
                    )
                    record.update({"status": "MATRIX_ERROR", "matrix_error": str(exc)})
                indexed_results.append((index, record))
                save_report(
                    metadata,
                    [item for _, item in sorted(indexed_results)],
                    json_path,
                    md_path,
                )
                print(
                    f"[{completed}/{len(jobs)}] {job.lane} {job.core.vlnv}"
                    f" -> {record['status']}",
                    flush=True,
                )
    results = [record for _, record in sorted(indexed_results)]
    save_report(metadata, results, json_path, md_path)
    print(f"JSON: {json_path}")
    print(f"Markdown: {md_path}")

    failing = {
        "SETUP_TIMEOUT",
        "SETUP_FAIL",
        "COMPILE_TIMEOUT",
        "FAIL",
        "RUNTIME_TIMEOUT",
        "RUNTIME_FAIL",
        "MATRIX_ERROR",
        "DEBT",
        "SETUP_DEBT",
    }
    return 1 if any(result["status"] in failing for result in results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
