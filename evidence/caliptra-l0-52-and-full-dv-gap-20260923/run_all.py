#!/usr/bin/env python3
"""Run the official Caliptra v2.1.2 Verilator L0 selection sequentially."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

BASE = Path(__file__).resolve().parent
SOURCE = BASE / "source"
ALIASES = BASE / "aliases"
RUNS = BASE / "runs_batch"
SVA_SHA256 = "7e832e09d1b95785db47226cc3dfaf1064771c14e413e354e7f66fd69938cac6"
SKIP = re.compile(r"smoke_test_(?:clk_gating|cg_wdt|mbox_cg|kv_cg|doe_cg|dma|wdt_rst)")


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def selected_tests():
    tests = []
    for line in (SOURCE / "src/integration/stimulus/L0_regression.yml").read_text().splitlines():
        match = re.match(r"\s*-\s+\.\./test_suites/(\S+?)/\S+\.yml\s*(?:#.*)?$", line)
        if not match:
            continue
        name = match.group(1)
        if not SKIP.search(name):
            tests.append(name)
    return tests


def prepare(env):
    if not SOURCE.is_dir() or not ALIASES.is_dir():
        raise RuntimeError("Expected pinned source/ and aliases/ directories")
    sva = SOURCE / "src/integration/asserts/caliptra_top_sva.sv"
    if sha256(sva) != SVA_SHA256:
        raise RuntimeError("Pinned SVA overlay hash mismatch")
    seed_run = BASE / "runs/iccm_lock"
    obj_dir = seed_run / "obj_dir"
    if not (obj_dir / "Vcaliptra_top_tb").is_file() or not (seed_run / "verilator-build").exists():
        raise RuntimeError("Missing reusable Verilator build in runs/iccm_lock")
    env.update({
        "PATH": f"{ALIASES}:{env['PATH']}",
        "CALIPTRA_ROOT": str(SOURCE),
        "CALIPTRA_WORKSPACE": str(BASE),
        "CALIPTRA_PRIM_ROOT": str(SOURCE / "src/caliptra_prim_generic"),
        "CALIPTRA_PRIM_MODULE_PREFIX": "caliptra_prim_generic",
        "CALIPTRA_AXI4PC_DIR": str(SOURCE / "src/integration/tb"),
    })
    RUNS.mkdir(exist_ok=True)
    return seed_run, obj_dir


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--resume", action="store_true", help="skip tests with complete result and all logs")
    parser.add_argument("--timeout", type=int, default=900, help="per command timeout in seconds")
    args = parser.parse_args()
    try:
        env = os.environ.copy()
        seed_run, obj_dir = prepare(env)
        tests = selected_tests()
        if len(tests) != 52:
            raise RuntimeError(f"Expected official selection of 52 tests, found {len(tests)}")
        print(f"Official L0 Verilator selection: {len(tests)} tests", flush=True)
    except Exception as exc:
        print(f"setup error: {exc}", file=sys.stderr)
        return 2

    failures = 0
    for test in tests:
        run = RUNS / test
        result_path = RUNS / f"{test}.result.json"
        stdout_path, stderr_path = RUNS / f"{test}.make.stdout", RUNS / f"{test}.make.stderr"
        sim_path = run / "verilator_sim.log"
        if args.resume and result_path.is_file() and stdout_path.is_file() and stderr_path.is_file():
            try:
                previous = json.loads(result_path.read_text())
                if previous.get("complete") is True and (previous.get("passed") is not True or sim_path.is_file()):
                    print(f"SKIP {test}: completed result and logs are present", flush=True)
                    failures += previous.get("passed") is not True
                    continue
            except (ValueError, OSError):
                pass
        try:
            run.mkdir(parents=True, exist_ok=True)
            for link, target in ((run / "obj_dir", obj_dir), (run / "verilator-build", seed_run / "verilator-build")):
                if link.is_symlink():
                    link.unlink()
                elif link.exists():
                    raise RuntimeError(f"Refusing to replace existing path: {link}")
                link.symlink_to(target, target_is_directory=target.is_dir())
        except Exception as exc:
            print(f"setup error for {test}: {exc}", file=sys.stderr)
            return 2
        sim_path.unlink(missing_ok=True)

        common = ["/usr/bin/make", "-C", str(run), "-f", str(SOURCE / "tools/scripts/Makefile"),
                  f"TESTNAME={test}", "CALIPTRA_INTERNAL_TRNG=1", "PLAYBOOK_RANDOM_SEED=1",
                  "BUILD_CFLAGS=-std=gnu11 -O2", "VERILATOR=verilator -Wno-MISINDENT"]
        firmware_cmd = common + ["program.hex"]
        sim_cmd = ["./obj_dir/Vcaliptra_top_tb", "+CLP_REGRESSION"]
        metadata = {
            "test": test, "commands": [firmware_cmd, sim_cmd], "timeout_seconds_per_command": args.timeout,
            "cwd": str(run), "environment_overrides": {k: env[k] for k in (
                "CALIPTRA_ROOT", "CALIPTRA_WORKSPACE", "CALIPTRA_PRIM_ROOT",
                "CALIPTRA_PRIM_MODULE_PREFIX", "CALIPTRA_AXI4PC_DIR")},
            "path_prefix": str(ALIASES), "pinned_release": "Caliptra v2.1.2 49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e",
            "selected_overlay_sha256": SVA_SHA256,
        }
        (RUNS / f"{test}.command.json").write_text(json.dumps(metadata, indent=2) + "\n")
        start = time.monotonic()
        codes, timed_out = [], []
        with stdout_path.open("wb") as out, stderr_path.open("wb") as err:
            for command in (firmware_cmd, sim_cmd):
                try:
                    if command is sim_cmd:
                        with sim_path.open("wb") as sim_log:
                            proc = subprocess.run(command, cwd=run, env=env, stdout=sim_log,
                                                  stderr=subprocess.STDOUT, timeout=args.timeout)
                    else:
                        proc = subprocess.run(command, cwd=run, env=env, stdout=out, stderr=err, timeout=args.timeout)
                    codes.append(proc.returncode)
                    timed_out.append(False)
                except subprocess.TimeoutExpired:
                    codes.append(None)
                    timed_out.append(True)
                    break
                if codes[-1] != 0:
                    break
        sim_text = sim_path.read_text(errors="replace") if sim_path.exists() else ""
        elf = run / f"{test}.exe"
        arch = None
        if elf.is_file():
            readelf = subprocess.run([str(ALIASES / "riscv64-unknown-elf-readelf"), "-A", str(elf)], capture_output=True, text=True)
            arch = next((line.strip() for line in readelf.stdout.splitlines() if "Tag_RISCV_arch:" in line), None)
        passed_markers = sim_text.count("* TESTCASE PASSED")
        failed_markers = sim_text.count("TESTCASE FAILED") + sim_text.count("TEST FAILED")
        sva_errors = sim_text.count("SVA ERROR:")
        passed = (len(codes) == 2 and codes == [0, 0] and sim_path.is_file()
                  and passed_markers > 0 and failed_markers == 0 and sva_errors == 0)
        result = {
            "test": test, "complete": True, "passed": passed, "command_exit_codes": codes,
            "timed_out": timed_out, "elapsed_seconds": round(time.monotonic() - start, 2),
            "pass_banners": passed_markers, "fail_banners": failed_markers, "sva_error_count": sva_errors,
            "sim_log_exists": sim_path.is_file(), "firmware_elf": str(elf) if elf.is_file() else None,
            "firmware_elf_size_bytes": elf.stat().st_size if elf.is_file() else None,
            "firmware_elf_arch_attribute": arch,
            "logs": [str(stdout_path), str(stderr_path)] + ([str(sim_path)] if sim_path.is_file() else []),
        }
        result_path.write_text(json.dumps(result, indent=2) + "\n")
        print(json.dumps(result), flush=True)
        failures += not passed
    print(f"L0 result: {len(tests)} selected, {failures} failed or incomplete", flush=True)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
