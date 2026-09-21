#!/usr/bin/env python3
"""Check SAT/UNSAT and injected UNKNOWN value/RNG semantics in both editions."""
import os
from pathlib import Path
import platform
import shlex
import subprocess
import tempfile

here = Path(__file__).resolve().parent
root = here.parent.parent
ivl = os.environ.get("IVERILOG", str(root / "local-install/bin/iverilog"))
vvp = os.environ.get("VVP", str(root / "vvp/vvp"))
system = platform.system()
if system not in ("Darwin", "Linux"):
    raise SystemExit("Unsupported test interposer platform: " + system)
with tempfile.TemporaryDirectory(prefix="scope-solver-unknown-") as tmp:
    lib = Path(tmp) / "unknown.so"
    flags = ["-dynamiclib", "-undefined", "dynamic_lookup"] if system == "Darwin" else ["-shared", "-fPIC"]
    subprocess.run(shlex.split(os.environ.get("CC", "cc")) + flags +
                   [str(here / "scope_solver_unknown.c"), "-o", str(lib)], check=True)
    for edition in ("2017", "2023"):
        for fixture, injected in (("scope_solver_sat_unsat", False),
                                  ("scope_solver_unknown", False),
                                  ("scope_solver_unknown", True)):
            binary = Path(tmp) / "test.vvp"
            subprocess.run([ivl, "-g" + edition, "-o", str(binary),
                            str(here / (fixture + ".sv"))], check=True)
            env = os.environ.copy()
            env.pop("LD_PRELOAD", None)
            env.pop("DYLD_INSERT_LIBRARIES", None)
            args = [vvp, str(binary)]
            if injected:
                env["DYLD_INSERT_LIBRARIES" if system == "Darwin" else "LD_PRELOAD"] = str(lib)
                args.append("+expect_unknown")
            result = subprocess.run(args, env=env, capture_output=True, text=True, timeout=30)
            assert result.returncode == 0, result.stdout + result.stderr
            assert "PASSED" in result.stdout, result.stdout
            if injected:
                assert "INJECTED:" in result.stderr, result.stderr
                assert "ERROR: scope randomization solver returned UNKNOWN" in result.stderr, result.stderr
            else:
                assert "UNKNOWN" not in result.stderr, result.stderr
            print("PASS", edition, fixture, "injected" if injected else "normal")
