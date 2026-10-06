"""Check that matrix subprocess output is visible before a run exits."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time

import opentitan_matrix


def check_live_log(memory_limit_bytes: int | None) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        log_path = root / "runtime.log"
        code = (
            "import time\n"
            "print('READY')\n"
            "time.sleep(1.5)\n"
            "print('DONE')\n"
        )
        result: dict[str, object] = {}
        errors: list[BaseException] = []

        def run() -> None:
            try:
                options = {
                    "cwd": Path.cwd(),
                    "env": os.environ.copy(),
                    "timeout": 10,
                    "live_log_path": log_path,
                }
                if memory_limit_bytes is not None:
                    options["memory_limit_bytes"] = memory_limit_bytes
                result["value"] = opentitan_matrix.command_result(
                    [sys.executable, "-c", code], **options
                )
            except BaseException as error:
                errors.append(error)

        worker = threading.Thread(target=run)
        worker.start()
        deadline = time.monotonic() + 0.75
        while time.monotonic() < deadline and not log_path.exists():
            if errors:
                raise errors[0]
            time.sleep(0.01)
        assert log_path.exists(), "live log was not created"

        deadline = time.monotonic() + 0.75
        while time.monotonic() < deadline and "READY" not in log_path.read_text():
            if errors:
                raise errors[0]
            time.sleep(0.01)
        assert "READY" in log_path.read_text(), "child output was not streamed"
        assert "DONE" not in log_path.read_text(), "test child exited too early"

        worker.join(timeout=5)
        assert not worker.is_alive(), "matrix subprocess did not exit"
        if errors:
            raise errors[0]
        completed = result["value"]
        assert completed.returncode == 0
        assert completed.output == "READY\nDONE\n"


def demo() -> None:
    check_live_log(None)
    if Path("/usr/bin/footprint").is_file():
        check_live_log(2 * 1024**3)


if __name__ == "__main__":
    demo()
    print("PASS live matrix subprocess log")
