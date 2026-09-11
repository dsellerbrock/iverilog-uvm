#!/usr/bin/env python3
"""Check native lifecycle records, independently of UVM attribute support."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile

compiler, runtime, backend = (str(Path(arg).resolve()) for arg in sys.argv[1:])
source = Path(__file__).with_name("recording_lifecycle.sv")
for edition in ("2017", "2023"):
    with tempfile.TemporaryDirectory(prefix="ivl-recording-") as directory:
        cwd = Path(directory)
        compile_result = subprocess.run(
            [compiler, "-g" + edition, "-m", backend, "-s", "main", "-o", "sim.vvp", str(source)],
            cwd=cwd, text=True, capture_output=True, timeout=60)
        assert compile_result.returncode == 0, compile_result.stdout + compile_result.stderr
        result = subprocess.run([runtime, "sim.vvp"], cwd=cwd, text=True,
                                capture_output=True, timeout=60)
        output = result.stdout + result.stderr
        assert result.returncode == 0 and "PASSED\n" in output, output
        assert "DPI error:" not in output, output
        assert output.count("IVL_UVM_RECORD_ERROR:") == 8, output
        a, b = ([json.loads(line) for line in (cwd / filename).read_text().splitlines()]
                for filename in ("a.jsonl", "b.jsonl"))
        assert [row["event"] for row in a] == ["open", "stream", "begin", "end", "free", "free", "close"], a
        assert [row["event"] for row in b] == ["open", "stream", "begin", "link", "link", "free", "free", "close"], b
        assert {row["owner"] for row in a} == {1} and {row["owner"] for row in b} == {2}
        assert a[1]["name"] == 'a\n"\\name', a[1]
        assert a[2]["handle"] == 3 and a[2]["stream"] == 1
        assert b[2]["handle"] == 4 and b[2]["stream"] == 2
        assert int(a[2]["begin_time"]) == 0xfffffffffffffff0
        assert int(b[2]["begin_time"]) == 0xfffffffffffffff1
        assert int(a[3]["end_time"]) == 0xfffffffffffffff2
        assert (b[3]["left"], b[3]["right"], b[3]["left_owner"], b[3]["right_owner"]) == (3, 4, 1, 2)
        assert b[3]["relation"] == "child"
        assert (b[4]["left"], b[4]["right"], b[4]["left_owner"], b[4]["right_owner"]) == (4, 3, 2, 1)
        assert all(row["tick"] == "0" for row in a + b)
        print("PASS: native recording lifecycle IEEE " + edition)

# Exercise a real write/flush failure. Windows lacks POSIX per-process file
# limits; its ordinary lifecycle checks above still run.
if sys.platform != "win32":
    import resource
    import signal

    def limit_journal():
        signal.signal(signal.SIGXFSZ, signal.SIG_IGN)
        resource.setrlimit(resource.RLIMIT_FSIZE, (64, 64))

    with tempfile.TemporaryDirectory(prefix="ivl-recording-io-") as directory:
        subprocess.run([compiler, "-g2017", "-m", backend, "-s", "main", "-o", "sim.vvp", str(source)],
                       cwd=directory, check=True, capture_output=True, timeout=60)
        result = subprocess.run([runtime, "sim.vvp", "+io_failure"], cwd=directory,
                                text=True, capture_output=True, timeout=60,
                                preexec_fn=limit_journal)
        output = result.stdout + result.stderr
        assert result.returncode == 1 and "POISON_REJECTED" in output, output
        assert "journal write/flush failed" in output and "unknown or failed recorder owner" in output, output
        print("PASS: native journal I/O failure poisons recorder and fails simulation")
