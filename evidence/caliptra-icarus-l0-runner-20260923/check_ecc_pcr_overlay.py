#!/usr/bin/env python3
"""Check the PCR checker patch on a disposable source copy only."""

from pathlib import Path
import runpy
import shutil

runner = runpy.run_path(str(Path(__file__).with_name("run.py")), run_name="overlay_check")
source = runner["ECC_PCR_SOURCE"]
profile = runner["PROFILE"]
before = runner["sha256"](source)
copied_profile, copied = runner["prepare_ecc_pcr_overlay"](profile)
try:
    assert before == runner["ECC_PCR_SOURCE_SHA256"] == runner["sha256"](source)
    assert runner["sha256"](copied) == runner["ECC_PCR_PATCHED_SHA256"]
    old = "${CALIPTRA_ROOT}/src/ecc/rtl/ecc_dsa_ctrl.sv"
    assert profile.read_text().splitlines().count(old) == 1
    assert copied_profile.read_text() == profile.read_text().replace(old, str(copied))
finally:
    shutil.rmtree(copied_profile.parent)
print("PCR checker copied patch and profile substitution: PASS")
