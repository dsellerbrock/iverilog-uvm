"""Check native MLDSA against a pinned KAT and the exact SV file exchange."""

import hashlib
import subprocess
import sys
import tempfile
from pathlib import Path

adams_root = Path(sys.argv[1])
helper = Path(sys.argv[2]).resolve()
kat_dir = adams_root / "src/abr_top/uvmf/Dilithium_ref/dilithium/ref/test"

with tempfile.TemporaryDirectory() as directory:
    directory = Path(directory)

    def run(name, lines):
        source = directory / (name + "_input.hex")
        output = directory / (name + "_output.hex")
        source.write_text("\n".join(lines) + "\n")
        subprocess.run([helper, source, output], check=True, capture_output=True)
        return output.read_text().splitlines()

    kat_output = directory / "kat_output.hex"
    subprocess.run(
        [helper, kat_dir / "keygen_input_KAT1.hex", kat_output],
        check=True,
        capture_output=True,
    )
    expected = (kat_dir / "keygen_KAT1_expected.hex").read_bytes()
    assert kat_output.read_bytes() == expected
    print("keygen: pinned KAT1 matches byte for byte", hashlib.sha256(expected).hexdigest())

    seed = bytes(range(32)).hex().upper()
    message = bytes(range(64)).hex().upper()
    key = run("keygen", ["00", seed])
    assert list(map(len, key)) == [2, 5184, 9792]
    signed = run("sign", ["01", message, key[2]])
    assert list(map(len, signed)) == [2, 8, 9254, 8, 128]
    assert signed[4] == message
    verified = run("verify", ["02", signed[2], message, key[1]])
    assert verified[0:2] == ["02", "0"]
    print("testbench keygen/sign/verify protocol: result 0")

    wrong_signature = ("0" if signed[2][0] != "0" else "1") + signed[2][1:]
    rejected = run("verify_bad", ["02", wrong_signature, message, key[1]])
    assert rejected[0] == "02" and rejected[1] != "0"
    print("tampered signature: rejected")
