#!/usr/bin/env python3
"""Rerun the 37 UVM cases whose corrected-run logs lacked the UVM DPI module."""
import json
import os
import pathlib
import signal
import subprocess
import sys
import tempfile


RUN = pathlib.Path(__file__).resolve().parent
CORPUS = RUN / "corpus/repo"
TESTS = RUN / "evidence/tests"
INSTALL = RUN / "install"
DPI_MODULE_DIR = RUN / "dpi-module"
LOGS = RUN / "logs/uvm-tests"
MANIFEST = RUN / "manifest.json"
def relocate(arg):
    return arg.replace("@CORPUS@", str(CORPUS)).replace("@TESTS@", str(TESTS))


def has_report(output, severity):
    return any(line.startswith(f"{severity} @") for line in output.splitlines())


def run_one(argv, cwd, log_path, timeout_seconds):
    process = subprocess.Popen(argv, cwd=cwd, text=True, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, start_new_session=True)
    try:
        output, _ = process.communicate(timeout=timeout_seconds)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            output, _ = process.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            output, _ = process.communicate()
        log_path.write_text(output)
        return 124, output
    log_path.write_text(output)
    return process.returncode, output


def main():
    assert CORPUS.is_dir() and TESTS.is_dir()
    assert (DPI_MODULE_DIR / "uvm_dpi.vpi").is_file()
    assert (INSTALL / "bin/iverilog").is_file() and (INSTALL / "bin/vvp").is_file()
    sys.path.insert(0, str(CORPUS / "tools"))
    from logparser import parseLog

    manifest = json.loads(MANIFEST.read_text())
    assert len(manifest) == 37, f"expected 37 pinned UVM cases, got {len(manifest)}"
    assert len({row["test_path"] for row in manifest}) == 37
    LOGS.mkdir(parents=True, exist_ok=True)

    results = []
    for index, row in enumerate(manifest, 1):
        assert row["expected_result"] == "pass"
        work = LOGS / f"{index:02d}-{pathlib.Path(row['test_path']).stem}"
        work.mkdir(parents=True, exist_ok=True)
        compile_log = work / "compile.log"
        run_log = work / "run.log"
        compile_args = [relocate(arg) for arg in row["compile_args"]]
        assert "-g2012" in compile_args
        assert any(arg.endswith("/uvm_pkg.sv") for arg in compile_args)
        assert any(arg.endswith("/" + row["test_path"]) for arg in compile_args)
        compile_rc, compile_output = run_one(
            [str(INSTALL / "bin/iverilog"), *compile_args], work, compile_log,
            row["timeout_seconds"])
        if compile_rc == 0:
            run_rc, run_output = run_one(
                [str(INSTALL / "bin/vvp"), f"-M{DPI_MODULE_DIR}", "-muvm_dpi",
                 "iverilog.out", *row["run_args"]], work, run_log,
                row["timeout_seconds"])
        else:
            run_rc, run_output = None, ""
        output = compile_output + run_output
        try:
            parse_pass = parseLog(run_output) if run_rc == 0 else False
            parse_error = None
        except Exception as exc:
            parse_pass = False
            parse_error = str(exc)
        record = {
            "test_path": row["test_path"],
            "compile_rc": compile_rc,
            "run_rc": run_rc,
            "timed_out": compile_rc == 124 or run_rc == 124,
            "dpi_error": "DPI error:" in output,
            "uvm_error": has_report(output, "UVM_ERROR"),
            "uvm_fatal": has_report(output, "UVM_FATAL"),
            "assertion_lines": sum(":assert:" in line for line in run_output.splitlines()),
            "sv_tests_parse_pass": parse_pass,
            "sv_tests_parse_error": parse_error,
            "compile_log": str(compile_log.relative_to(RUN)),
            "run_log": str(run_log.relative_to(RUN)) if compile_rc == 0 else None,
        }
        results.append(record)
        print(f"{index}/{len(manifest)} {row['test_path']}: compile={compile_rc} run={run_rc} "
              f"DPI-error={record['dpi_error']} UVM-error={record['uvm_error']} "
              f"UVM-fatal={record['uvm_fatal']} asserts={record['assertion_lines']}",
              flush=True)

    summary = {
        "cases": len(results),
        "compile_failures": sum(r["compile_rc"] != 0 for r in results),
        "runtime_nonzero": sum(r["run_rc"] not in (0, None) for r in results),
        "timeouts": sum(r["timed_out"] for r in results),
        "missing_dpi_symbol_logs": sum(r["dpi_error"] for r in results),
        "uvm_error_logs": sum(r["uvm_error"] for r in results),
        "uvm_fatal_logs": sum(r["uvm_fatal"] for r in results),
        "assertion_cases": sum(r["assertion_lines"] > 0 for r in results),
        "sv_tests_parse_pass": sum(r["sv_tests_parse_pass"] for r in results),
        "results": results,
    }
    (RUN / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(json.dumps({k: v for k, v in summary.items() if k != "results"}, indent=2), flush=True)


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test-timeout"]:
        assert has_report("UVM_ERROR @ 10: env [E] failure", "UVM_ERROR")
        assert not has_report("UVM_ERROR :    0", "UVM_ERROR")
        assert has_report("UVM_FATAL @ 10: env [F] failure", "UVM_FATAL")
        assert not has_report("UVM_FATAL :    0", "UVM_FATAL")
        with tempfile.TemporaryDirectory() as tmp:
            log = pathlib.Path(tmp) / "timeout.log"
            rc, _ = run_one(["/bin/sh", "-c", "sleep 10 & wait"], pathlib.Path(tmp), log, 0.2)
            assert rc == 124, f"expected process-group timeout, got exit {rc}"
            assert log.is_file()
        print("process-group timeout self-check passed")
    else:
        main()
