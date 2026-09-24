"""Check the native helper against pinned Adams Bridge ML-KEM KATs."""

import re
import subprocess
import sys
import tempfile
from pathlib import Path

adams_root = Path(sys.argv[1])
helper = Path(sys.argv[2]).resolve()
sequence_dir = (
    adams_root
    / "src/abr_top/uvmf/uvmf_template_output/project_benches/mldsa/tb/sequences/src"
)


def kat(name, prefix):
    text = (sequence_dir / name).read_text()
    return dict(re.findall(rf"{prefix}\[0\]\.([\w]+) = \"([0-9A-F]+)\";", text))


keygen = kat("ML_KEM_keygen_KATs_sequence.svh", "keygen_kats")
encap = kat("ML_KEM_encaps_KATs_sequence.svh", "encaps_kats")

with tempfile.TemporaryDirectory() as directory:
    directory = Path(directory)
    for operation, input_lines, expected_lines in (
        (
            "1",
            [keygen["seed_z"], keygen["seed_d"]],
            [keygen["seed_z"], keygen["seed_d"], keygen["expected_PK"], keygen["expected_SK"]],
        ),
        (
            "2",
            [encap["msg"], encap["ek"]],
            [encap["msg"], encap["ek"], encap["shared_key"], encap["ciphertext"]],
        ),
    ):
        source = directory / "input.txt"
        output = directory / "output.txt"
        source.write_text("\n".join([operation, *input_lines]) + "\n")
        subprocess.run([helper, operation, "-i", source, "-o", output], check=True)
        assert output.read_text().splitlines() == [operation, *expected_lines]
        print(f"operation {operation}: pinned KAT matches byte for byte")

    source.write_text("1\n" + "Z" * 64 + "\n" + keygen["seed_d"] + "\n")
    failed = subprocess.run([helper, "1", "-i", source, "-o", output], capture_output=True)
    assert failed.returncode != 0 and b"invalid hex" in failed.stderr
    print("malformed input: rejected")
