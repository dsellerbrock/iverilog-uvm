import importlib.util
import os
import pathlib
import subprocess
import tempfile
import unittest


SCRIPT = pathlib.Path(__file__).with_name("sync_pr_branches.py")
SPEC = importlib.util.spec_from_file_location("sync_pr_branches", SCRIPT)
SYNC = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SYNC)


def git(*args, check=True):
    result = subprocess.run(args, check=check, capture_output=True, text=True)
    return result


class ConflictResolutionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temp.name)
        self.cwd = os.getcwd()
        os.chdir(self.root)
        git("git", "init", "-b", "main")
        git("git", "config", "user.name", "Conflict test")
        git("git", "config", "user.email", "conflict-test@example.invalid")

        self.paths = (
            "docs/conformance/BLOCKERS.md",
            ".ai/ACTIVE_WORK.yaml",
            "src/example.cc",
        )
        for name in self.paths:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("\n".join(f"line-{n}" for n in range(1, 8)) + "\n")
        git("git", "add", ".")
        git("git", "commit", "-m", "base")
        self.base = git("git", "rev-parse", "HEAD").stdout.strip()

    def tearDown(self):
        os.chdir(self.cwd)
        self.temp.cleanup()

    def edit(self, name, first, middle=None, tail=False):
        lines = [f"line-{n}" for n in range(1, 8)]
        lines[0] = first
        if middle:
            lines[middle - 1] = f"main-line-{middle}"
        if tail:
            lines.append("pr-tail")
        (self.root / name).write_text("\n".join(lines) + "\n")

    def test_preferred_side_wins_conflict_hunk_and_other_hunks_survive(self):
        git("git", "switch", "-c", "pr")
        for name in self.paths:
            self.edit(name, "pr-line-1", tail=True)
        git("git", "commit", "-am", "PR changes")

        git("git", "switch", "-c", "main-edit", self.base)
        self.edit(self.paths[0], "main-line-1", middle=3)
        self.edit(self.paths[1], "main-line-1", middle=3)
        self.edit(self.paths[2], "main-line-1", middle=5)
        git("git", "commit", "-am", "main changes")
        git("git", "switch", "pr")
        merge = git("git", "merge", "--no-commit", "--no-ff", "main-edit", check=False)
        self.assertEqual(merge.returncode, 1, merge.stderr)

        self.assertEqual(SYNC.resolve_conflicts(), 3)
        expected = (
            ["main-line-1", "line-2", "main-line-3", "line-4", "line-5", "line-6", "line-7", "pr-tail"],
            ["pr-line-1", "line-2", "main-line-3", "line-4", "line-5", "line-6", "line-7", "pr-tail"],
            ["pr-line-1", "line-2", "line-3", "line-4", "main-line-5", "line-6", "line-7", "pr-tail"],
        )
        for name, lines in zip(self.paths, expected):
            self.assertEqual((self.root / name).read_text().splitlines(), lines)
        self.assertEqual(git("git", "ls-files", "-u").stdout, "")


if __name__ == "__main__":
    unittest.main()
