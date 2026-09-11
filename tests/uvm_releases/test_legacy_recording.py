#!/usr/bin/env python3
"""Exercise original UVM 1.1d callbacks with the explicit native recorder."""
import json
import os
import shlex
from pathlib import Path
import re
import subprocess
import sys
import tempfile

compiler, runtime, backend, home, includes = (str(Path(arg).resolve()) for arg in sys.argv[1:])
source = Path(__file__).with_name("recording_legacy.sv")
for edition in ("2017", "2023"):
    with tempfile.TemporaryDirectory(prefix="ivl-legacy-recording-") as directory:
        root = Path(directory)
        program = root / "sim.vvp"
        c = subprocess.run([compiler, "-g" + edition, "-I", str(Path(home) / "src"),
                            "-I", includes, "-m", backend, "-s", "main", "-o", str(program),
                            str(Path(home) / "src/uvm_pkg.sv"), str(source)],
                           cwd=root, text=True, capture_output=True, timeout=120)
        assert c.returncode == 0, c.stdout + c.stderr
        scenarios = ["normal", "wrong_owner", "existing_text", "rollback", "rollback_transaction", "switch_recorder"]
        if os.name == "posix":
            scenarios.extend(("replaced_text", "rollback_io"))
        for scenario in scenarios:
            cwd = root / scenario
            cwd.mkdir()
            text_log = cwd / "legacy-a.jsonl.uvm.log"
            if scenario == "existing_text":
                text_log.write_text("PRESERVE THIS LOG\n")
            args = [runtime, str(program)] + (["+" + scenario] if scenario in ("wrong_owner", "rollback", "rollback_io", "rollback_transaction", "switch_recorder") else [])
            if scenario == "replaced_text":
                code = "from pathlib import Path; p=Path('legacy-a.jsonl.uvm.log'); p.rename('retained.log'); p.write_text('PRESERVE REPLACEMENT\\n')"
                args.append("+replace_text=" + shlex.join([sys.executable, "-c", code]))
            def limit_file_size():
                import resource
                import signal
                signal.signal(signal.SIGXFSZ, signal.SIG_IGN)
                resource.setrlimit(resource.RLIMIT_FSIZE, (180, 180))
            r = subprocess.run(args, cwd=cwd, text=True, capture_output=True, timeout=60,
                               preexec_fn=limit_file_size if scenario == "rollback_io" else None)
            output = r.stdout + r.stderr
            if scenario == "existing_text":
                assert r.returncode == 1 and "Cannot create legacy recording text log" in output, output
                assert text_log.read_text() == "PRESERVE THIS LOG\n"
                continue
            if scenario in ("rollback", "rollback_io", "rollback_transaction"):
                kind = "transaction" if scenario == "rollback_transaction" else "stream"
                assert r.returncode == 1 and "Cannot register native recording " + kind in output, output
                assert "ROLLBACK_PASSED" in output and "ROLLBACK_FAILED" not in output, output
                assert ("journal write/flush failed" if scenario == "rollback_io" else "already registered") in output, output
                assert ("BEGIN" if scenario == "rollback_transaction" else "CREATE_STREAM") in text_log.read_text()
                continue
            if scenario == "wrong_owner":
                assert r.returncode == 1 and "Cannot end native recording transaction" in output, output
                assert "wrong-owner" in output, output
                b = [json.loads(line) for line in (cwd / "legacy-b.jsonl").read_text().splitlines()]
                component = next(row["handle"] for row in b if row["event"] == "begin" and row["name"] == "component-tx")
                assert not any(row["event"] in ("end", "free") and row.get("handle") == component for row in b)
                continue
            assert r.returncode == 0, output
            assert not re.search(r"DPI error:|IVL_UVM_RECORD_ERROR:|FATAL:|UVM_(?:ERROR|FATAL)", output), output
            match = re.search(r"LEGACY_RECORDING_PASSED parent=(\d+) child=(\d+) component=(\d+) transaction=(\d+)", output)
            assert match, output
            parent, child, component, transaction = map(int, match.groups())
            a, b = ([json.loads(line) for line in (cwd / name).read_text().splitlines()]
                    for name in ("legacy-a.jsonl", "legacy-b.jsonl"))
            assert a[0]["event"] == b[0]["event"] == "open"
            assert a[-1]["event"] == b[-1]["event"] == "close"
            assert {row["owner"] for row in a} == {1} and {row["owner"] for row in b} == {2}
            links = [(row["left"], row["right"], row["left_owner"], row["right_owner"], row["relation"])
                     for row in b if row["event"] == "link"]
            assert links == [(parent, child, 1, 2, "child"), (child, parent, 2, 1, "after_end"),
                             (component, transaction, 2, 1, "")], links
            for rows, handle, begin, end in ((a, parent, 10, 12), (b, child, 11, 13),
                                           (a, transaction, 20, 21), (b, component, 20, 21)):
                events = [row for row in rows if row.get("handle") == handle]
                assert [row["event"] for row in events] == ["begin", "end", "free"], events
                assert int(events[0]["begin_time"]) == begin and int(events[1]["end_time"]) == end
            assert sum(row["event"] == "stream" for row in a) == (3 if scenario == "switch_recorder" else 2)
            if scenario == "switch_recorder":
                switched = re.search(r"SWITCH_PASSED component=(\d+) transaction=(\d+)", output)
                assert switched, output
                switched_component, switched_transaction = map(int, switched.groups())
                stream_a = next(row["handle"] for row in a if row["event"] == "stream" and row["name"] == "component-stream")
                stream_b = next(row["handle"] for row in b if row["event"] == "stream" and row["name"] == "component-stream")
                assert stream_a != stream_b
                for h in (switched_component, switched_transaction):
                    events = [row for row in a if row.get("handle") == h]
                    assert [row["event"] for row in events] == ["begin", "end", "free"], events
                    assert events[0]["begin_time"] == "30" and events[1]["end_time"] == "31"
                assert next(row for row in a if row.get("handle") == switched_component)["stream"] == stream_a
                assert [(row["left"], row["right"], row["left_owner"], row["right_owner"])
                        for row in a if row["event"] == "link"] == [(switched_component, switched_transaction, 1, 1)]
            assert sum(row["event"] == "stream" for row in b) == 2
            for name in ("legacy-a.jsonl.uvm.log", "legacy-b.jsonl.uvm.log"):
                if scenario == "replaced_text" and name == "legacy-a.jsonl.uvm.log":
                    assert (cwd / name).read_text() == "PRESERVE REPLACEMENT\n"
                    name = "retained.log"
                text = (cwd / name).read_text()
                assert "CREATE_STREAM" in text and "BEGIN" in text and "END" in text and "FREE" in text
        print("PASS: original 1.1d recorder/component lifecycle IEEE " + edition)
