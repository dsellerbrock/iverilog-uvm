#!/usr/bin/env python3
"""Focused tests for the JSON benchmark result helpers."""

import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_json


class JsonRunnerHelpersTest(unittest.TestCase):
    def test_hash_covers_outputs_but_ignores_staged_inputs(self):
        with tempfile.TemporaryDirectory() as temp:
            left = Path(temp) / "left"
            right = Path(temp) / "right"
            for directory in (left, right):
                (directory / ".inputs").mkdir(parents=True)
                (directory / "stdout.bin").write_bytes(b"same output\n")
                (directory / "trace.vcd").write_bytes(b"same waveform")
            (left / ".inputs" / "mem.hex").write_bytes(b"input one")
            (right / ".inputs" / "mem.hex").write_bytes(b"input two")

            self.assertEqual(run_json.hash_outputs(left), run_json.hash_outputs(right))
            (right / "trace.vcd").write_bytes(b"different waveform")
            self.assertNotEqual(run_json.hash_outputs(left), run_json.hash_outputs(right))

    def test_large_memory_input_is_stable_and_complete(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            run_json.stage_inputs("large_memory", root)
            fixture = root / "large_memory.hex"
            first = fixture.read_text(encoding="ascii")
            self.assertEqual(len(first.splitlines()), run_json.LARGE_MEMORY_WORDS)
            self.assertEqual(first.splitlines()[0], "00000000")
            self.assertEqual(first.splitlines()[-1], "00003fff")
            run_json.stage_inputs("large_memory", root)
            self.assertEqual(fixture.read_text(encoding="ascii"), first)

    def test_perf_stat_parser_handles_values_and_unavailable_events(self):
        parsed = run_json.parse_perf_stat(
            "12345,,instructions,\n12.50,msec,task-clock,"
        )
        self.assertEqual(parsed, {"instructions": 12345, "task_clock_ms": 12.5})
        parsed = run_json.parse_perf_stat(
            "<not supported>,,instructions,\n"
        )
        self.assertEqual(parsed, {"instructions": None, "task_clock_ms": None})

    def test_perf_wraps_time_so_rss_is_measured_for_the_simulator(self):
        time_command = ["/usr/bin/time", "-f", "%M", "-o", "rss.txt", "--", "vvp"]
        with patch.object(run_json, "time_wrapped", return_value=time_command):
            command = run_json.measurement_command(
                ["vvp"], "rss.txt", "/usr/bin/perf", "perf.csv"
            )
        self.assertEqual(command[-len(time_command):], time_command)
        self.assertEqual(command[0:2], ["/usr/bin/perf", "stat"])

    def test_run_process_enforces_its_timeout(self):
        with self.assertRaisesRegex(TimeoutError, "timed out after 0.05s"):
            run_json.run_process(
                [sys.executable, "-c", "import time; time.sleep(10)"], timeout=0.05
            )

    def test_compare_outputs_requires_exact_file_contents(self):
        with tempfile.TemporaryDirectory() as temp:
            left = Path(temp) / "left"
            right = Path(temp) / "right"
            left.mkdir()
            right.mkdir()
            (left / "stdout.bin").write_bytes(b"same")
            (right / "stdout.bin").write_bytes(b"same")
            self.assertTrue(run_json.compare_outputs(left, right))
            (right / "stdout.bin").write_bytes(b"same\n")
            self.assertFalse(run_json.compare_outputs(left, right))

    def test_summary_reports_median_and_relative_spread(self):
        summary = run_json.summarize_samples([1.0, 2.0, 3.0, 4.0, 5.0])
        self.assertEqual(summary["median"], 3.0)
        self.assertAlmostEqual(summary["spread_pct"], 400.0 / 3.0)


if __name__ == "__main__":
    unittest.main()
