#!/usr/bin/env python3
"""Replay doe_scan with failure-only SVA diagnostics in a fresh build dir."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

BASE = Path(__file__).resolve().parent
SOURCE = BASE / "source"
RUN = BASE / "runs" / "doe_scan_probe"
RUN.mkdir(parents=True, exist_ok=True)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


sva = SOURCE / "src/integration/asserts/caliptra_top_sva.sv"
assert "DOE_SCAN_PROBE antecedent sample" in sva.read_text()
env = os.environ.copy()
env.update({
    "PATH": f"{BASE / 'aliases'}:{env['PATH']}",
    "CALIPTRA_ROOT": str(SOURCE), "CALIPTRA_WORKSPACE": str(BASE),
    "CALIPTRA_PRIM_ROOT": str(SOURCE / "src/caliptra_prim_generic"),
    "CALIPTRA_PRIM_MODULE_PREFIX": "caliptra_prim_generic",
    "CALIPTRA_AXI4PC_DIR": str(SOURCE / "src/integration/tb"),
})
command = [
    "/usr/bin/make", "-C", str(RUN), "-f", str(SOURCE / "tools/scripts/Makefile"),
    "TESTNAME=smoke_test_doe_scan", "CALIPTRA_INTERNAL_TRNG=1",
    "PLAYBOOK_RANDOM_SEED=1", "BUILD_CFLAGS=-std=gnu11 -O2",
    "VERILATOR=verilator -Wno-MISINDENT",
    "VERILATOR_RUN_ARGS=+CLP_REGRESSION", "verilator",
]
metadata = {
    "command": command, "source_sva_sha256": digest(sva),
    "probe_patch_sha256": digest(BASE / "doe_scan_probe.patch"),
    "selected_kv_overlay_sha256": "7e832e09d1b95785db47226cc3dfaf1064771c14e413e354e7f66fd69938cac6",
    "release": "Caliptra v2.1.2 49370266d; Adams Bridge v2.0.3 b77e3d",
    "toolchain": "xPack GCC 15.2.0-1 rv32imc/ilp32",
    "scope": "Diagnostic run only; assertion remains enabled",
}
(BASE / "doe_scan_probe.command.json").write_text(json.dumps(metadata, indent=2) + "\n")
started = time.monotonic()
with (BASE / "doe_scan_probe.make.stdout").open("wb") as out, (BASE / "doe_scan_probe.make.stderr").open("wb") as err:
    try:
        process = subprocess.run(command, env=env, stdout=out, stderr=err, timeout=1200)
        code, timed_out = process.returncode, False
    except subprocess.TimeoutExpired:
        code, timed_out = None, True
sim = RUN / "verilator_sim.log"
contents = sim.read_text(errors="replace") if sim.is_file() else ""
result = {
    "exit_code": code, "timed_out": timed_out,
    "elapsed_seconds": round(time.monotonic() - started, 2),
    "sim_log_sha256": digest(sim) if sim.is_file() else None,
    "pass_banners": contents.count("* TESTCASE PASSED"),
    "sva_error_count": contents.count("SVA ERROR:"),
    "probe_lines": [line for line in contents.splitlines() if "DOE_SCAN_PROBE" in line],
    "source_sva_sha256": digest(sva),
    "probe_patch_sha256": metadata["probe_patch_sha256"],
}
result["passed"] = (code == 0 and not timed_out and result["pass_banners"] == 1
                    and result["sva_error_count"] == 0)
(BASE / "doe_scan_probe.result.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps({key: result[key] for key in ("exit_code", "timed_out", "pass_banners", "sva_error_count", "probe_lines")}))
sys.exit(0 if result["passed"] else 124 if timed_out else code or 1)
