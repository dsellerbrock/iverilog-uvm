#!/usr/bin/env python3
"""Replay one pinned Caliptra Verilator L0 test in an isolated directory."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

BASE = Path(__file__).resolve().parent
SOURCE = BASE / "source"
ALIASES = BASE / "aliases"
TEST = sys.argv[1] if len(sys.argv) == 2 else "iccm_lock"
RUN = BASE / "runs" / TEST
RUN.mkdir(parents=True, exist_ok=True)
TEST_PATCHES = {
    "smoke_test_hw_config": ("hw_config_inline_candidate.patch", "src/integration/test_suites/smoke_test_hw_config/caliptra_isr.h"),
    "smoke_test_hmac_errortrigger": ("hmac_errortrigger_stdlib_candidate.patch", "src/integration/test_suites/smoke_test_hmac_errortrigger/smoke_test_hmac_errortrigger.c"),
}

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()

assert (SOURCE / "src/integration/test_suites" / TEST).is_dir(), TEST
assert sha256(SOURCE / "src/integration/asserts/caliptra_top_sva.sv") == "7e832e09d1b95785db47226cc3dfaf1064771c14e413e354e7f66fd69938cac6"
env = os.environ.copy()
env.update({
    "PATH": f"{ALIASES}:{env['PATH']}",
    "CALIPTRA_ROOT": str(SOURCE),
    "CALIPTRA_WORKSPACE": str(BASE),
    "CALIPTRA_PRIM_ROOT": str(SOURCE / "src/caliptra_prim_generic"),
    "CALIPTRA_PRIM_MODULE_PREFIX": "caliptra_prim_generic",
    "CALIPTRA_AXI4PC_DIR": str(SOURCE / "src/integration/tb"),
})
argv = [
    "/usr/bin/make", "-C", str(RUN), "-f", str(SOURCE / "tools/scripts/Makefile"),
    f"TESTNAME={TEST}", "CALIPTRA_INTERNAL_TRNG=1", "PLAYBOOK_RANDOM_SEED=1",
    "BUILD_CFLAGS=-std=gnu11 -O2", "VERILATOR=verilator -Wno-MISINDENT", "VERILATOR_RUN_ARGS=+CLP_REGRESSION", "verilator",
]
metadata = {
    "argv": argv,
    "cwd": os.getcwd(),
    "environment_overrides": {k: env[k] for k in ("CALIPTRA_ROOT", "CALIPTRA_WORKSPACE", "CALIPTRA_PRIM_ROOT", "CALIPTRA_PRIM_MODULE_PREFIX", "CALIPTRA_AXI4PC_DIR")},
    "path_prefix": str(ALIASES),
    "pinned_release": "Caliptra v2.1.2 49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e",
    "selected_overlay_sha256": sha256(SOURCE / "src/integration/asserts/caliptra_top_sva.sv"),
    "selected_test_patch_sha256": sha256(BASE / TEST_PATCHES[TEST][0]) if TEST in TEST_PATCHES else None,
    "selected_test_source_sha256": sha256(SOURCE / TEST_PATCHES[TEST][1]) if TEST in TEST_PATCHES else None,
    "toolchain": "xPack GNU RISC-V Embedded GCC 15.2.0-1 darwin-arm64",
}
(BASE / f"{TEST}.command.json").write_text(json.dumps(metadata, indent=2) + "\n")
started = time.monotonic()
with (BASE / f"{TEST}.make.stdout").open("wb") as stdout, (BASE / f"{TEST}.make.stderr").open("wb") as stderr:
    try:
        process = subprocess.run(argv, cwd=BASE, env=env, stdout=stdout, stderr=stderr, timeout=900)
        code = process.returncode
        timed_out = False
    except subprocess.TimeoutExpired:
        code = None
        timed_out = True
sim = RUN / "verilator_sim.log"
sim_text = sim.read_text(errors="replace") if sim.exists() else ""
elf = RUN / f"{TEST}.exe"
arch = None
if elf.exists():
    readelf = subprocess.run([str(ALIASES / "riscv64-unknown-elf-readelf"), "-A", str(elf)], capture_output=True, text=True)
    arch = next((line.strip() for line in readelf.stdout.splitlines() if "Tag_RISCV_arch:" in line), None)
result = {
    "test": TEST,
    "exit_code": code,
    "timed_out": timed_out,
    "elapsed_seconds": round(time.monotonic() - started, 2),
    "sim_log_exists": sim.exists(),
    "testcase_passed_markers": sim_text.count("* TESTCASE PASSED"),
    "testcase_failed_markers": sim_text.count("TESTCASE FAILED") + sim_text.count("TEST FAILED"),
    "sva_error_lines": sim_text.count("SVA ERROR:"),
    "firmware_elf_sha256": sha256(elf) if elf.exists() else None,
    "firmware_arch_attribute": arch,
    "sim_log_sha256": sha256(sim) if sim.exists() else None,
    "stdout_sha256": sha256(BASE / f"{TEST}.make.stdout"),
    "stderr_sha256": sha256(BASE / f"{TEST}.make.stderr"),
    "selected_test_patch_sha256": metadata["selected_test_patch_sha256"],
    "selected_test_source_sha256": metadata["selected_test_source_sha256"],
}
result["passed"] = (code == 0 and not timed_out and sim.exists()
                    and result["testcase_passed_markers"] == 1
                    and result["testcase_failed_markers"] == 0
                    and result["sva_error_lines"] == 0)
(BASE / f"{TEST}.result.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
sys.exit(0 if result["passed"] else 124 if timed_out else code or 1)
