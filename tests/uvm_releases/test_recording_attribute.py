#!/usr/bin/env python3
"""U15: lossless native attribute capture. Companion to test_recording.py,
which is deliberately independent of attribute support.

Verifies, against tests/uvm_releases/recording_attribute.sv, in both IEEE
editions: a multi-word signed packed value with x/z bits (every aval/bval
word, reconstructed independently of the C++ encoder via struct-level
arithmetic below, not a value merely echoed back), an exact IEEE 754 real
(cross-checked against Python's own struct.pack, not a pinned magic string),
a string variable, a raw string literal with an embedded zero byte (which a
string variable cannot legally hold per 6.16, so only the literal path
proves losslessness -- this is U15's actual dependency on L32), three
non-literal string expressions (an enum .name(), a function-call result, and
a runtime concatenation -- these route through __vpiVThrStrStack, which
rejects vpiVectorVal outright and reports vpiSize in characters rather than
bits like a literal's __vpiStringConst does; DD048), and that an unknown,
wrong-kind (stream, not transaction), already-ended and already-freed
transaction handle are all rejected with no attribute row written and a
nonzero simulation exit status.
"""
import json
import struct
from pathlib import Path
import subprocess
import sys
import tempfile

compiler, runtime, backend = (str(Path(arg).resolve()) for arg in sys.argv[1:])
source = Path(__file__).with_name("recording_attribute.sv")


def run(edition, plusargs, cwd):
    compile_result = subprocess.run(
        [compiler, "-g" + edition, "-m", backend, "-s", "main", "-o", "sim.vvp", str(source)],
        cwd=cwd, text=True, capture_output=True, timeout=60)
    assert compile_result.returncode == 0, compile_result.stdout + compile_result.stderr
    return subprocess.run([runtime, "sim.vvp", *plusargs], cwd=cwd, text=True,
                          capture_output=True, timeout=60)


def words_to_bytes_le(hexstr, nwords):
    """Reverse the encoder's per-word byte layout: each 8 hex chars are 4
    raw bytes in the printed (little-endian-within-word) order."""
    out = []
    for w in range(nwords):
        chunk = hexstr[w * 8:(w + 1) * 8]
        out.append(bytes.fromhex(chunk))
    return out


for edition in ("2017", "2023"):
    with tempfile.TemporaryDirectory(prefix="ivl-recattr-happy-") as directory:
        cwd = Path(directory)
        result = run(edition, [], cwd)
        output = result.stdout + result.stderr
        assert result.returncode == 0 and "HAPPY_TEST_COMPLETED\n" in output, output
        assert "IVL_UVM_RECORD_ERROR:" not in output, output
        # The non-literal string cases must never hit __vpiVThrStrStack's
        # rejected-format diagnostic (vvp/vpi_vthr_vector.cc); if this
        # reappears, the length-mismatch heuristic in uvm_recording.cc is
        # speculatively attempting vpiVectorVal on an ordinary string again.
        assert "vvp error: get" not in output, output
        rows = [json.loads(line) for line in (cwd / "happy.jsonl").read_text().splitlines()]
        attrs = {row["name"]: row for row in rows if row["event"] == "attribute"}
        assert set(attrs) == {
            "packed", "real", "string_var", "string_literal",
            "string_enum_name", "string_func_result", "string_concat",
        }, attrs

        p = attrs["packed"]
        assert p["kind"] == "packed" and p["size"] == 65 and p["signed"] is True, p
        assert p["packed_words"] == 3, p
        # 65'h1_80000000_x000000z, reconstructed word-by-word (word0 = LSBs).
        aval_words = words_to_bytes_le(p["packed_aval"], 3)
        bval_words = words_to_bytes_le(p["packed_bval"], 3)
        w0_a = int.from_bytes(aval_words[0], "little")
        w0_b = int.from_bytes(bval_words[0], "little")
        w1_a = int.from_bytes(aval_words[1], "little")
        w1_b = int.from_bytes(bval_words[1], "little")
        w2_a = int.from_bytes(aval_words[2], "little")
        w2_b = int.from_bytes(bval_words[2], "little")
        assert (w0_a, w0_b) == (0xF0000000, 0xF000000F), (hex(w0_a), hex(w0_b))
        assert (w1_a, w1_b) == (0x80000000, 0x00000000), (hex(w1_a), hex(w1_b))
        assert (w2_a, w2_b) == (0x00000001, 0x00000000), (hex(w2_a), hex(w2_b))

        r = attrs["real"]
        assert r["kind"] == "real", r
        assert float(r["real_decimal"]) == 1.2345678901234567, r
        expected_bits = struct.pack("<d", 1.2345678901234567).hex()
        assert r["real_bits"] == expected_bits, (r["real_bits"], expected_bits)

        sv = attrs["string_var"]
        assert sv["kind"] == "string" and sv["value"] == "line\nquote\"\\tail", sv

        en = attrs["string_enum_name"]
        assert en["kind"] == "string" and en["value"] == "GREEN", en
        fr = attrs["string_func_result"]
        assert fr["kind"] == "string" and fr["value"] == "hello", fr
        cc = attrs["string_concat"]
        assert cc["kind"] == "string" and cc["value"] == "ab", cc

        sl = attrs["string_literal"]
        assert sl["kind"] == "string_literal" and sl["size"] == 40, sl
        nbytes = sl["size"] // 8
        nwords = (sl["size"] + 31) // 32
        aval_words = words_to_bytes_le(sl["string_aval"], nwords)
        recovered = bytearray(nbytes)
        for j in range(nbytes):
            word_bytes = aval_words[j // 4]
            recovered[nbytes - 1 - j] = word_bytes[j % 4]
        assert bytes(recovered) == b"\x00AB\x00C", bytes(recovered)

        print("PASS: native recording attribute capture (happy path) IEEE " + edition)

    with tempfile.TemporaryDirectory(prefix="ivl-recattr-reject-") as directory:
        cwd = Path(directory)
        result = run(edition, ["+reject_test"], cwd)
        output = result.stdout + result.stderr
        assert result.returncode != 0, output
        assert "REJECT_TEST_COMPLETED\n" in output, output
        assert output.count("IVL_UVM_RECORD_ERROR:") == 4, output
        rows = [json.loads(line) for line in (cwd / "reject.jsonl").read_text().splitlines()]
        assert not any(row["event"] == "attribute" for row in rows), rows
        assert [row["event"] for row in rows] == \
            ["open", "stream", "begin", "begin", "end", "begin", "free", "close"], rows

        print("PASS: native recording attribute capture (rejection paths) IEEE " + edition)
