#!/usr/bin/env python3
"""Create a disposable, one-line Caliptra reset-startup diagnostic overlay."""

from hashlib import sha256
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: prepare_overlay.py /tmp/output-directory")

campaign = Path(__file__).resolve().parents[2]
source = campaign.parent / "caliptra-rtl/src/integration/tb/caliptra_top_tb_soc_bfm.sv"
profile = campaign / "evidence/caliptra-l0-icarus-baseline-20260923/caliptra_top_tb_icarus_profile.vf"
output = Path(sys.argv[1]).resolve()
if not output.is_relative_to(Path("/tmp").resolve()):
    raise SystemExit("diagnostic overlay output must be under /tmp")

expected = {
    source: "e0c60be6ad48681458ca38093a494ae263304997e658c5eefa006881da10ae06",
    profile: "577861eb1c4c9a26ada2379f55e3215d097e1cc317804a0f3155c3786ed381f2",
}
for path, digest in expected.items():
    if sha256(path.read_bytes()).hexdigest() != digest:
        raise SystemExit(f"source hash changed: {path}")

old = b"    initial begin\n        cptra_pwrgood = 1'b0;\n        BootFSM_BrkPoint ="
new = b"    initial begin\n        #0 cptra_pwrgood = 1'b0;\n        BootFSM_BrkPoint ="
data = source.read_bytes()
if data.count(old) != 1:
    raise SystemExit("expected BFM startup context is missing or duplicated")

old_entry = b"${CALIPTRA_ROOT}/src/integration/tb/caliptra_top_tb_soc_bfm.sv"
profile_data = profile.read_bytes()
if profile_data.count(old_entry) != 1:
    raise SystemExit("expected filelist entry is missing or duplicated")

output.mkdir(parents=True, exist_ok=True)
source_copy = output / source.name
source_copy.write_bytes(data.replace(old, new))
filelist_copy = output / profile.name
filelist_copy.write_bytes(profile_data.replace(old_entry, str(source_copy).encode()))
print(f"overlay={source_copy}")
print(f"filelist={filelist_copy}")
print(f"overlay_sha256={sha256(source_copy.read_bytes()).hexdigest()}")
print(f"filelist_sha256={sha256(filelist_copy.read_bytes()).hexdigest()}")
