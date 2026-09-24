#!/usr/bin/env python3
"""Run the exact 52 released Caliptra L0 cases with at most four Icarus jobs."""

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
RUNNER = ROOT / "evidence/caliptra-icarus-l0-runner-20260923/run.py"
SELECTION = RUNNER.with_name("selected_52.txt")
SOURCE = ROOT.parent / "caliptra-rtl"
TOOLCHAIN = ROOT.parent / "evidence/caliptra-exact-riscv-toolchain-20260923/toolchain/bin"
QUALIFICATION = "diagnostic_reset_checker_source_ephemeral_jtag_port_overlay"
PIN = "49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e"
ADAMS_PIN = "b77e3d899e828d626cfc2a0d26a6b5704cc121e0"
JTAG_EPHEMERAL_TOP_SHA256 = "df8d51cc7ad84000288f5d7c19641f433d59ae213314fa81b9d9e5f8a6b76c6e"
FINGERPRINT_KEYS = {"runner", "compiler", "ivl", "vvp_target", "vvp", "profile",
                    "jtagdpi", "reset_bfm_overlay", "checker_sva_overlay", "checker_patch",
                    "jtag_top_source", "jtag_top_overlay", "jtag_profile_input"}
STABLE_FINGERPRINT_KEYS = FINGERPRINT_KEYS - {"profile", "jtag_profile_input"}


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def gcc_fingerprints():
    return {tool: sha256(TOOLCHAIN / f"riscv-none-elf-{tool}")
            for tool in ("gcc", "cpp", "as", "objcopy", "objdump", "size")}


def names():
    selected = SELECTION.read_text().splitlines()
    if len(selected) != 52 or len(set(selected)) != 52 or any(
        not re.fullmatch(r"[A-Za-z0-9_]+", name) for name in selected
    ):
        raise RuntimeError("Selection must contain exactly 52 distinct, safe names")
    released = subprocess.check_output([sys.executable, str(RUNNER), "--list"],
                                       cwd=ROOT, text=True).splitlines()
    if selected != released:
        raise RuntimeError("Frozen selection differs from the pinned release runner")
    return selected


def command(name, output):
    return [sys.executable, str(RUNNER), "--commercial-unsafe", "--reset-overlay",
            "--checker-source-overlay", "--ephemeral-jtag-port", "--case", name,
            "--timeout", "1800", "--output", str(output / "cases" / name)]


def run_one(name, output):
    log = output / "logs" / f"{name}.log"
    with log.open("w") as stream:
        try:
            code = subprocess.run(command(name, output), cwd=ROOT, stdout=stream,
                                  stderr=subprocess.STDOUT, check=False).returncode
        except OSError as exc:
            stream.write(f"Runner launch failed: {exc}\n")
            code = 127
    return name, code


def read_json(path):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return None


def stable_fingerprints_match(fingerprints):
    if not fingerprints:
        return True
    if any(not STABLE_FINGERPRINT_KEYS <= item.keys() for item in fingerprints):
        return False
    first = {key: fingerprints[0][key] for key in STABLE_FINGERPRINT_KEYS}
    return all(all(item[key] == first[key] for key in STABLE_FINGERPRINT_KEYS)
               for item in fingerprints[1:])


def classify(name, exit_code, summary, result):
    if not isinstance(summary, dict):
        return "INCOMPLETE", "missing or invalid summary"
    if summary.get("status") == "INVALIDATED":
        return "INVALIDATED", "per-case source or tool integrity failed"
    if summary.get("status") == "BLOCKED":
        return "BLOCKED", summary.get("blocker", "per-case setup blocked")
    if not isinstance(result, dict):
        return "INCOMPLETE", "missing or invalid completed result"
    released_case = result.get("released_case")
    if (summary.get("status") != "COMPLETE" or summary.get("selected") != 52
            or summary.get("attempted") != 1 or summary.get("unrun") != 51
            or (summary.get("passed"), summary.get("failed")) not in ((1, 0), (0, 1))
            or result.get("test") != name
            or not isinstance(released_case, dict) or released_case.get("name") != name):
        return "INCOMPLETE", "case identity or completion count mismatch"
    for record in (summary, result):
        if (record.get("qualification") != QUALIFICATION
                or record.get("commercial_unsafe") is not True
                or record.get("reset_overlay") is not True
                or record.get("checker_source_overlay") is not True
                or record.get("ephemeral_jtag_port") is not True
                or not isinstance(record.get("jtag_port_provenance"), dict)):
            return "INVALIDATED", "compatibility profile mismatch"
    jtag = summary["jtag_port_provenance"]
    if (jtag != result["jtag_port_provenance"]
            or jtag.get("listen_port_after") != 0
            or jtag.get("source_sha256_after") != JTAG_EPHEMERAL_TOP_SHA256):
        return "INVALIDATED", "ephemeral JTAG source or port mismatch"
    source = summary.get("source_integrity_before")
    if (not isinstance(source, dict) or source != summary.get("source_integrity_after")
            or source.get("caliptra_commit") != PIN or source.get("caliptra_clean") is not True
            or source.get("adams_bridge_commit") != ADAMS_PIN
            or source.get("adams_bridge_clean") is not True
            or summary.get("source_integrity_error") is not None
            or result.get("source_integrity_ok") is not True):
        return "INVALIDATED", "pinned source integrity mismatch"
    fingerprints = summary.get("fingerprints_before")
    if (not isinstance(fingerprints, dict) or not FINGERPRINT_KEYS <= fingerprints.keys()
            or fingerprints != summary.get("fingerprints_after")
            or summary.get("fingerprint_integrity_error") is not None
            or result.get("fingerprint_integrity_ok") is not True):
        return "INVALIDATED", "per-case tool fingerprint mismatch"
    if (fingerprints["jtag_top_overlay"] != JTAG_EPHEMERAL_TOP_SHA256
            or jtag.get("profile_sha256_after") != fingerprints["profile"]
            or jtag.get("profile_sha256_before") != fingerprints["jtag_profile_input"]):
        return "INVALIDATED", "ephemeral JTAG profile fingerprint mismatch"
    flags = summary.get("compiler_flags")
    if (summary.get("compile_sampling_warnings") != 0
            or result.get("compile_sampling_warnings") != 0
            or not isinstance(flags, list) or "-gcommercial-unsafe" not in flags):
        return "INVALIDATED", "compiler profile or sampling warning mismatch"
    if result.get("passed") is True:
        if (exit_code != 0 or summary.get("passed") != 1 or summary.get("failed") != 0
                or result.get("firmware_exit") != 0 or result.get("sim_exit") != 0
                or result.get("firmware_timeout") or result.get("sim_timeout")
                or result.get("pass_markers") != 1 or result.get("failed_markers") != 0
                or result.get("bad_diagnostics") != 0 or result.get("missing_dpi_symbols") != 0
                or result.get("jtag_server_errors") != 0
                or result.get("native_vector_integrity_ok") is not True
                or result.get("expected_smoke_readmemh_match") is False
                or result.get("missing_readmemh") != []
                or any(not isinstance(result.get(key), int) or result[key] <= 0 for key in
                       ("retired_instructions", "cycles", "trace_commits"))):
            return "INVALIDATED", "claimed pass disagrees with unchanged L0 gate"
        return "PASS", None
    if result.get("passed") is False and summary.get("passed") == 0 and summary.get("failed") == 1:
        return "FAIL", "completed case failed its L0 gate"
    return "INVALIDATED", "per-case pass count mismatch"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="new sweep output directory")
    parser.add_argument("--jobs", type=int, choices=range(1, 5), default=4)
    parser.add_argument("--plan", action="store_true", help="print commands without writing or running")
    args = parser.parse_args()
    selected = names()
    output = args.output.resolve()
    if args.plan:
        print(json.dumps({"selected": len(selected), "jobs": args.jobs,
                          "commands": [command(name, output) for name in selected]}, indent=2))
        return 0
    if output == SOURCE or SOURCE in output.parents:
        parser.error("sweep output must not be inside pinned Caliptra sources")
    help_text = subprocess.check_output([sys.executable, str(RUNNER), "--help"],
                                        cwd=ROOT, text=True)
    if "--ephemeral-jtag-port" not in help_text:
        parser.error("per-case runner lacks --ephemeral-jtag-port")
    before = {"selection": sha256(SELECTION), "runner": sha256(RUNNER),
              "gcc_tools": gcc_fingerprints()}
    output.mkdir(parents=True, exist_ok=False)
    (output / "logs").mkdir()
    (output / "cases").mkdir()
    exits = {}
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = {pool.submit(run_one, name, output): name for name in selected}
        for future in as_completed(futures):
            name, code = future.result()
            exits[name] = code
            print(f"{name}: runner exit {code}", flush=True)
    records = []
    for name in selected:
        case_output = output / "cases" / name
        summary = read_json(case_output / "summary.json")
        result = read_json(case_output / name / "result.json")
        outcome, reason = classify(name, exits[name], summary, result)
        records.append({"name": name, "outcome": outcome, "reason": reason,
                        "runner_exit": exits[name], "output": str(case_output),
                        "runner_log": str(output / "logs" / f"{name}.log"),
                        "retired_instructions": result.get("retired_instructions") if isinstance(result, dict) else None,
                        "trace_commits": result.get("trace_commits") if isinstance(result, dict) else None})
    complete_summaries = [read_json(output / "cases" / name / "summary.json")
                          for name in selected]
    fingerprints = [s["fingerprints_before"] for s in complete_summaries
                    if isinstance(s, dict) and isinstance(s.get("fingerprints_before"), dict)]
    after = {"selection": sha256(SELECTION), "runner": sha256(RUNNER),
             "gcc_tools": gcc_fingerprints()}
    integrity_error = None
    if before != after:
        integrity_error = "selection or per-case runner changed during sweep"
    elif not stable_fingerprints_match(fingerprints):
        integrity_error = "stable per-case tool/source fingerprints differ across sweep"
    counts = {kind: sum(record["outcome"] == kind for record in records)
              for kind in ("PASS", "FAIL", "BLOCKED", "INVALIDATED", "INCOMPLETE")}
    attempted = counts["PASS"] + counts["FAIL"]
    passed = counts["PASS"] if integrity_error is None else 0
    status = ("INVALIDATED" if integrity_error else "COMPLETE" if attempted == 52
              else "INCOMPLETE")
    aggregate = {"qualification": QUALIFICATION, "selected": 52, "launched": len(exits),
                 "attempted": attempted, "passed": passed, "failed": counts["FAIL"],
                 "unrun_or_invalid": 52 - attempted + (counts["PASS"] if integrity_error else 0),
                 "status": status,
                 "outcomes": counts, "integrity_error": integrity_error,
                 "sweep_fingerprints_before": before, "sweep_fingerprints_after": after,
                 "cases": records}
    (output / "summary.json").write_text(json.dumps(aggregate, indent=2) + "\n")
    print(f"{status}: {passed}/52 patched diagnostic passes; {counts}", flush=True)
    return 0 if status == "COMPLETE" and passed == 52 else 1


if __name__ == "__main__":
    sys.exit(main())
