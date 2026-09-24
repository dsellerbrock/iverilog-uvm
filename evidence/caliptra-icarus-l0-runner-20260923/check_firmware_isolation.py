#!/usr/bin/env python3
"""Check per-case firmware patch isolation against the pinned Caliptra tree."""

import json
from pathlib import Path
import runpy
import tempfile

here = Path(__file__).resolve().parent
runner = runpy.run_path(str(here / "run.py"), run_name="runner_check")
source = runner["SOURCE"]
patches = runner["FIRMWARE_PATCHES"]
sha256 = runner["sha256"]
expected = {row["name"]: row["selected_overlay"] for row in
            json.loads((here / "firmware_overlay_build_check.json").read_text())["results"]}
names = [case["name"] for case in runner["cases"]()]
assert len(names) == 52
original = {name: sha256(source / relative) for name, (_, relative) in patches.items()}
runner["verify_sources"]()

with tempfile.TemporaryDirectory(prefix="caliptra-firmware-isolation-") as temporary:
    roots, overlays = runner["prepare_firmware_overlays"](
        Path(temporary), [{"name": name} for name in names])
    assert all(roots[name] == source for name in names if name not in patches)
    assert len({roots[name] for name in names}) == 3
    assert set(overlays) == set(patches)
    for name in patches:
        for field in ("patch_sha256", "source_sha256_before", "source_sha256_after"):
            assert overlays[name][field] == expected[name][field]
        for target_name, (_, relative) in patches.items():
            digest = (expected[name]["source_sha256_after"] if target_name == name
                      else original[target_name])
            assert sha256(roots[name] / relative) == digest
    assert runner["verify_firmware_overlays"](roots, overlays) is None

    other = "smoke_test_hmac_errortrigger"
    other_file = roots["smoke_test_hw_config"] / patches[other][1]
    other_file.write_bytes(other_file.read_bytes() + b"\n")
    try:
        runner["verify_firmware_overlays"](roots, overlays)
    except RuntimeError as exc:
        assert "Firmware source isolation failed" in str(exc)
    else:
        raise AssertionError("Unselected patch-target mutation was accepted")

assert {name: sha256(source / relative) for name, (_, relative) in patches.items()} == original
runner["verify_sources"]()
print("per-case firmware source isolation: PASS")
