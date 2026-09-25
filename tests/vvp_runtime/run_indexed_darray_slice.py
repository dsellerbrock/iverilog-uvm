#!/usr/bin/env python3
"""Paired IEEE 1800-2017/2023 indexed dynamic-array slice checks."""

import os
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
SOURCES = ROOT / "ivtest" / "ivltests"
CASES = {
    "read": "PASS indexed dynamic-array read",
    "write": "PASS indexed dynamic-array write",
    "overlap": "PASS indexed dynamic-array overlap",
    "control": "PASS dynamic-array slice control",
}


def run(command):
    return subprocess.run(command, text=True, capture_output=True, timeout=30)


def main():
    compiler = os.environ.get("IVERILOG", "iverilog")
    runtime = os.environ.get("VVP", "vvp")
    with tempfile.TemporaryDirectory(prefix="ivl-indexed-darray-") as directory:
        for edition in (2017, 2023):
            for name in (*CASES, "size_mismatch", "invalid", "too_wide",
                         "too_wide_base"):
                output = Path(directory) / f"{name}-{edition}.vvp"
                source = SOURCES / f"sv_dynamic_array_indexed_slice_{name}.v"
                compiled = run([compiler, f"-g{edition}", "-s", "test",
                                "-o", str(output), str(source)])
                diagnostic = compiled.stdout + compiled.stderr
                if name == "invalid":
                    okay = (compiled.returncode != 0
                            and diagnostic.count("slice width must be") == 3
                            and diagnostic.count("slice base must be") == 2
                            and diagnostic.count("doesn't match the context type") == 1)
                elif name == "too_wide":
                    okay = (compiled.returncode != 0
                            and diagnostic.count("width exceeds the 65536-element lowering limit") == 1)
                elif name == "too_wide_base":
                    okay = (compiled.returncode != 0
                            and diagnostic.count("base wider than 127 bits is not yet supported") == 2)
                else:
                    okay = compiled.returncode == 0 and not diagnostic
                    if okay:
                        simulated = run([runtime, "-n", str(output)])
                        transcript = simulated.stdout + simulated.stderr
                        okay = simulated.returncode == 0 and not simulated.stderr
                        if name == "size_mismatch":
                            okay &= (transcript.count("ERROR:") == 1
                                     and "destination is unchanged" in transcript
                                     and "PRESERVED after indexed dynamic-array slice size error" in transcript)
                        else:
                            okay &= transcript.strip() == CASES[name]
                        diagnostic += transcript
                if not okay:
                    raise SystemExit(f"FAIL {edition} {name}:\n{diagnostic}")
    print("indexed dynamic-array slice: PASS 16/16")


if __name__ == "__main__":
    main()
