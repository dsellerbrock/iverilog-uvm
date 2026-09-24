#!/usr/bin/env python3
"""Check the opt-in JTAG port copy and the runtime server-error gate."""

from pathlib import Path
import runpy
import shutil

here = Path(__file__).resolve().parent
runner = runpy.run_path(str(here / "run.py"), run_name="runner_check")
source = runner["JTAG_TOP"]
original = source.read_bytes()
profile = runner["PROFILE"]
copied_profile, copied_top, provenance = runner["prepare_ephemeral_jtag_port"](profile)
try:
    assert source.read_bytes() == original
    assert copied_top.read_bytes() == original.replace(
        b".ListenPort     (63224)", b".ListenPort     (0)")
    assert original.count(b".ListenPort     (63224)") == 1
    assert runner["sha256"](copied_top) == runner["JTAG_EPHEMERAL_TOP_SHA256"]
    assert provenance["profile_sha256_before"] == runner["sha256"](profile)
    assert provenance["profile_sha256_after"] == runner["sha256"](copied_profile)
    assert profile.read_text().splitlines().count(
        "${CALIPTRA_ROOT}/src/integration/tb/caliptra_top_tb.sv") == 1
    assert copied_profile.read_text().splitlines().count(str(copied_top)) == 1
    assert "${CALIPTRA_ROOT}/src/integration/tb/caliptra_top_tb.sv" not in copied_profile.read_text()
finally:
    shutil.rmtree(copied_profile.parent)

jtag_errors = runner["JTAG_SERVER_ERROR"]
assert not jtag_errors.search("JTAG: Virtual JTAG interface jtag0 is listening on port 0. Use")
assert runner["runtime_diagnostics_ok"]("* TESTCASE PASSED\n")
for message in (
    "jtag0: Failed to bind socket: Address already in use (48)",
    "jtag0: Failed to listen on socket: Invalid argument (22)",
    "jtag0: Unable to create TCP server on port 0",
    "jtag0: Unable to create TCP socket thread",
    "jtag0: Socket read failed, port: 0",
):
    assert jtag_errors.search("* TESTCASE PASSED\n" + message), message
    assert not runner["runtime_diagnostics_ok"]("* TESTCASE PASSED\n" + message), message
assert not runner["BAD"].search("jtag0: Failed to bind socket: Address already in use (48)")
print("ephemeral JTAG port substitution and failure gate: PASS")
