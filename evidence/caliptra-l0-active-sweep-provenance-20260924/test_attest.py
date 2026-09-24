#!/usr/bin/env python3
"""Focused positive and tampered-top checks for the copied JTAG profile."""

import importlib.util
import json
from pathlib import Path
import tempfile

spec = importlib.util.spec_from_file_location("attest", Path(__file__).with_name("attest.py"))
attest = importlib.util.module_from_spec(spec)
spec.loader.exec_module(attest)

with tempfile.TemporaryDirectory() as temp:
    root = Path(temp)
    attest.SOURCE = root / "pinned"
    attest.JTAG_TOP = attest.SOURCE / "src/integration/tb/caliptra_top_tb.sv"
    attest.JTAG_TOP.parent.mkdir(parents=True)
    attest.JTAG_TOP.write_bytes(b"module tb;\n" + attest.JTAG_OLD + b"\nendmodule\n")
    case = root / "case"
    (case / "probe").mkdir(parents=True)
    copied = root / "copied_top.sv"
    copied.write_bytes(attest.JTAG_TOP.read_bytes().replace(attest.JTAG_OLD, attest.JTAG_NEW))
    before, after = root / "before.vf", root / "after.vf"
    before.write_text(attest.JTAG_ENTRY + "\n")
    after.write_text(str(copied) + "\n")
    provenance = {
        "source": str(attest.JTAG_TOP), "copied_source": str(copied),
        "source_sha256_before": attest.sha256(attest.JTAG_TOP),
        "source_sha256_after": attest.sha256(copied),
        "listen_port_before": 63224, "listen_port_after": 0,
        "profile_before": str(before), "profile_after": str(after),
        "profile_sha256_before": attest.sha256(before),
        "profile_sha256_after": attest.sha256(after),
    }
    (case / "compile.command.json").write_text(json.dumps({
        "argv": ["iverilog", "-f", str(after)], "jtag_port_provenance": provenance}))
    (case / "summary.json").write_text(json.dumps({"jtag_port_provenance": provenance}))
    (case / "probe/result.json").write_text(json.dumps({"jtag_port_provenance": provenance}))
    assert attest.verify_jtag_profile(case, "probe")["source_sha256"] == attest.sha256(copied)
    copied.write_bytes(copied.read_bytes() + b"// unexpected edit\n")
    try:
        attest.verify_jtag_profile(case, "probe")
    except RuntimeError:
        pass
    else:
        raise AssertionError("tampered top was accepted")

print("PASS: exact port overlay accepted; tampered top rejected")
