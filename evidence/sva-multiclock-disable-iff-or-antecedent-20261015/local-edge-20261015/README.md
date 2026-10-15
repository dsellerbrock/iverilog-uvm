# Inclusive attempt-boundary follow-up

The tested feature/test source is commit faf93ff5540c77b8c96d1caf2dffb2e286639785. The environment capture was made while those exact test changes were still uncommitted on base a50552d; the listed worktree diff is the test content in that commit.

The Mac run used:
~/codex-supervisor/localrun 5400 /Users/danielellerbrock/codex-supervisor/evidence/a3-m5-issue447-disable-iff-edge-20261015/run-local-t0-t1.sh

It exited 0 in 487.67 seconds; peak RSS was 1,269,596,160 bytes. The source build used clang 21.0.0, Bison 3.8.2, Autoconf 2.73 and make -j2.

- T0 issue-focused legacy: 8/8
- T0 issue-focused JSON/VVP: 8/8
- Smoke: compiler/VVP 56/56, VPI 131/131, negative checks 152/152, reproducers and runtime checks passed
- T1 fixed multiclock control: 30/30 legacy and 30/30 JSON/VVP
- T1 implication-tree neighbors: 1/1 legacy and 2/2 JSON/VVP
- T1 SVA NFA: 65/65

The captured environment, command, result, and compressed raw logs are in this directory.
