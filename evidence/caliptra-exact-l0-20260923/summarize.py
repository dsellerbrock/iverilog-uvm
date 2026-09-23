#!/usr/bin/env python3
"""Freeze the completed, unpatched 52-case Caliptra L0 sweep."""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
import re

from run_all import BASE, SOURCE, selected_tests


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def has_a_extension(attribute):
    isa = attribute.split('"')[1] if attribute and '"' in attribute else ""
    return bool(re.search(r"(?:^|_)a[0-9]", isa))


names = selected_tests()
assert len(names) == len(set(names)) == 52
records = []
for name in names:
    result_file = BASE / "runs_batch" / f"{name}.result.json"
    result = json.loads(result_file.read_text())
    assert result["test"] == name and result["complete"] is True
    sim_log = BASE / "runs_batch" / name / "verilator_sim.log"
    kind = ("pass" if result["passed"] else
            "firmware_build" if result["command_exit_codes"][0] != 0 else
            "sva_failure" if result["sva_error_count"] else "other_runtime")
    records.append({
        "test": name, "classification": kind,
        "result_sha256": digest(result_file),
        "sim_log_sha256": digest(sim_log) if sim_log.is_file() else None,
        "command_exit_codes": result["command_exit_codes"],
        "pass_banners": result["pass_banners"],
        "fail_banners": result["fail_banners"],
        "sva_error_count": result["sva_error_count"],
        "timed_out": result["timed_out"],
        "elf_arch": result["firmware_elf_arch_attribute"],
    })

passed = [entry for entry in records if entry["classification"] == "pass"]
assert len(passed) == 49
assert all(entry["command_exit_codes"] == [0, 0] and entry["pass_banners"] == 1
           and entry["fail_banners"] == entry["sva_error_count"] == 0
           and not any(entry["timed_out"]) and entry["sim_log_sha256"]
           and entry["elf_arch"] and not has_a_extension(entry["elf_arch"])
           for entry in passed)
assert {entry["classification"] for entry in records} == {
    "pass", "firmware_build", "sva_failure"}

source_files = [
    "src/integration/asserts/caliptra_top_sva.sv",
    "src/integration/test_suites/smoke_test_hw_config/caliptra_isr.h",
    "src/integration/test_suites/smoke_test_hmac_errortrigger/smoke_test_hmac_errortrigger.c",
]
summary = {
    "recorded_utc": datetime.now(timezone.utc).isoformat(),
    "scope": "Pinned-release Verilator L0 with selected KV SVA overlay; not full VCS/UVMF DV",
    "release": {
        "caliptra": "v2.1.2 49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e",
        "adams_bridge": "v2.0.3 b77e3d899e828d626cfc2a0d26a6b5704cc121e0",
    },
    "toolchain": {
        "name": "xPack GNU RISC-V Embedded GCC 15.2.0-1 darwin-arm64",
        "official_archive_sha256": "6588e8351455fad8aca37551f0e5a5543f3346bfa9a837cf03cbd3bdd4989f8f",
        "multilib": "rv32imc/ilp32",
    },
    "options": {
        "BUILD_CFLAGS": "-std=gnu11 -O2", "CALIPTRA_INTERNAL_TRNG": "1",
        "PLAYBOOK_RANDOM_SEED": "1", "VERILATOR": "verilator -Wno-MISINDENT",
        "sim_plusarg": "+CLP_REGRESSION", "command_timeout_seconds": 600,
    },
    "runner_sha256": digest(BASE / "run_all.py"),
    "source_file_sha256": {name: digest(SOURCE / name) for name in source_files},
    "result": {
        "selected": len(records), "passed": len(passed),
        "failed": len(records) - len(passed),
        "firmware_build_failures": sum(r["classification"] == "firmware_build" for r in records),
        "sva_failures": sum(r["classification"] == "sva_failure" for r in records),
        "timed_out": sum(any(r["timed_out"]) for r in records),
        "passed_elf_with_A_extension": sum(has_a_extension(r["elf_arch"]) for r in passed),
        "runner_exit_code": 1,
    },
    "tests": records,
}
out = BASE / "baseline_summary.json"
out.write_text(json.dumps(summary, indent=2) + "\n")
print(json.dumps(summary["result"]))
print(out)
