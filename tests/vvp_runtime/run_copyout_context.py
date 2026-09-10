#!/usr/bin/env python3
"""Malformed copy-out instructions must fail without crashing."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
runtime = os.environ.get("VVP", str(root / "vvp/vvp"))
prefix = """:ivl_version "13.0 (devel)";
:ivl_delay_selection "TYPICAL";
:vpi_time_precision + 0;
S_top .scope module, "top" "top" 1 1;
 .timescale 0 0;
v_x .var "x", 31 0;
S_f .scope autofunction.vec2.u32, "f" "f" 1 1, 1 1 0, S_top;
 .timescale 0 0;
 .scope S_top;
T_0 ;
"""
suffix = """    %end;
    .thread T_0;
:file_names 2;
    "N/A";
    "copyout_context.vvp";
"""
cases = [
    ("%copyout/leave;", "leave without enter"),
    ("%copyout/context 0;", "context without enter"),
    ("%copyout/enter S_top;", "requires an automatic scope"),
    ("%copyout/enter v_x;", "requires an automatic scope"),
    ("%copyout/enter S_f;", "has no returned callee frame"),
    ("%alloc S_f; %copyout/enter S_f; %copyout/context 2;", "invalid context mode"),
]
with tempfile.TemporaryDirectory(prefix="copyout-context-") as work:
    fixture = Path(work) / "test.vvp"
    for code, reason in cases:
        fixture.write_text(prefix + code.replace("; ", ";\n") + "\n" + suffix)
        result = subprocess.run([runtime, str(fixture)], capture_output=True,
                                text=True, timeout=10)
        expected = "runtime error: copy-out " + reason + "\n"
        assert result.returncode == 1 and not result.stdout and result.stderr == expected, (
            code, result.returncode, result.stdout, result.stderr)
print("PASS copy-out context malformed-bytecode checks (6/6)")
