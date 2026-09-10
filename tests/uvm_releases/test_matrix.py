"""Offline evidence-integrity controls for the UVM release probe."""
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile
import time
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "matrix", Path(__file__).resolve().parents[2] / "scripts/uvm_release_matrix.py")
matrix = importlib.util.module_from_spec(spec)
spec.loader.exec_module(matrix)


class MatrixTests(unittest.TestCase):
    def test_git_pin_and_local_changes_are_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            home = root / "library"
            home.mkdir()
            def git(*args):
                return subprocess.check_output(["git", "-C", str(home), *args], text=True).strip()
            git("init", "--quiet")
            source = home / "uvm_pkg.sv"
            source.write_text("original")
            git("add", "uvm_pkg.sv")
            git("-c", "user.name=Matrix Test", "-c", "user.email=matrix@example.invalid",
                "commit", "--quiet", "-m", "fixture")
            pinned = git("rev-parse", "HEAD")
            release = {"id": "fixture", "git": {"path": "library", "commit": pinned}}
            with patch.object(matrix, "REPO", root):
                self.assertEqual(matrix.acquire(release, root / "cache")[0], home)
                source.write_text("local work")
                with self.assertRaises(ValueError):
                    matrix.acquire(release, root / "cache")
                self.assertEqual(source.read_text(), "local work")
                self.assertEqual(git("rev-parse", "HEAD"), pinned)
                git("add", "uvm_pkg.sv")
                git("-c", "user.name=Matrix Test", "-c", "user.email=matrix@example.invalid",
                    "commit", "--quiet", "-m", "divergent fixture")
                divergent = git("rev-parse", "HEAD")
                with self.assertRaises(ValueError):
                    matrix.acquire(release, root / "cache")
                self.assertEqual(source.read_text(), "local work")
                self.assertEqual(git("rev-parse", "HEAD"), divergent)

    def test_success_requires_checks_and_clean_final_summary(self):
        result = {"returncode": 0, "timed_out": False}
        output = "UVM_RELEASE_SMOKE_PASSED\nUVM_ERROR : 0\nUVM_FATAL : 0\nUVM_WARNING : 0\n"
        self.assertTrue(matrix.smoke_passed(result, output))
        for bad in ("", output + "UVM_ERROR : 2\n", output + "UVM_WARNING : 1\n",
                    output.replace("UVM_RELEASE_SMOKE_PASSED", "prefix UVM_RELEASE_SMOKE_PASSED")):
            self.assertFalse(matrix.smoke_passed(result, bad))
        self.assertFalse(matrix.smoke_passed({"returncode": 1, "timed_out": False}, output))
        self.assertFalse(matrix.smoke_passed({"returncode": 0, "timed_out": True}, output))

    def test_archive_integrity_and_source_preservation(self):
        with tempfile.TemporaryDirectory() as directory:
            cache = Path(directory)
            (cache / "archives").mkdir()
            archive = cache / "archives/test.tar.gz"
            with tarfile.open(archive, "w:gz") as package:
                entry = tarfile.TarInfo("release/src/uvm_pkg.sv")
                entry.size = 1
                package.addfile(entry, io.BytesIO(b"x"))
            pin = {"id": "test", "sha256": matrix.digest(archive)}
            home, _, _ = matrix.acquire(pin, cache)
            matrix.acquire(pin, cache)
            (home / "src/uvm_pkg.sv").write_text("changed")
            with self.assertRaises(ValueError):
                matrix.acquire(pin, cache)
            with self.assertRaises(ValueError):
                matrix.acquire({"id": "test", "sha256": "0" * 64}, cache)

    def test_archive_cannot_escape(self):
        with tempfile.TemporaryDirectory() as directory:
            cache = Path(directory)
            (cache / "archives").mkdir()
            archive = cache / "archives/test.tar.gz"
            with tarfile.open(archive, "w:gz") as package:
                entry = tarfile.TarInfo("../../escaped")
                entry.size = 1
                package.addfile(entry, io.BytesIO(b"x"))
            with self.assertRaises(tarfile.FilterError):
                matrix.acquire({"id": "test", "sha256": matrix.digest(archive)}, cache)
            self.assertFalse((cache / "escaped").exists())

    def test_timeout_stops_descendants(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            result = matrix.execute(["sh", "-c", "(sleep 0.3; touch survived) & wait"],
                                    work, work / "timeout.log", 0.02)
            self.assertTrue(result["timed_out"])
            self.assertNotEqual(result["returncode"], 0)
            time.sleep(0.4)
            self.assertFalse((work / "survived").exists())

    def test_input_change_invalidates_saved_success(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            probe = work / "probe"
            probe.write_text("before")
            pins = {probe: matrix.digest(probe)}
            probe.write_text("after")
            results = {"results": [{"status": "SMOKE_PASS"}]}
            self.assertTrue(matrix.finalize(results, pins, work))
            saved = json.loads((work / "results.json").read_text())
            self.assertFalse(saved["baseline_valid"])
            self.assertEqual(saved["results"][0]["status"], "INVALIDATED_INPUT_CHANGE")


if __name__ == "__main__":
    unittest.main()
