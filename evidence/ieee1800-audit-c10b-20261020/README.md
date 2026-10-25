# IEEE 1800 §10.5 variable initialization probe

## Standards basis

IEEE 1800-2017/2023 §10.5 distinguishes variable declaration assignment from
net declaration assignment: a variable initializer is a one-time assignment
with no ongoing duration; a net declaration initializer behaves as a
continuous assignment. The same clause requires static variable initialization
before `initial` and `always` procedures begin. The wording is the same in both
editions for the tested behavior.

## Probe and result

`tests/1800_audit/c10/p10_05a_variable_initialization.sv` declares
`logic variable_init = source` and `wire net_init = source`, then changes
`source` after time zero. Under `-g2017` and `-g2023`, the compiler and VVP
both pass and print `PASS variable=0 net=1`: the variable retains its one-time
value, while the net follows its continuous assignment.

The paired local run was wrapped in `~/codex-supervisor/localrun` and each
compile/run command had a 60-second timeout. It took 0.45 s and peaked at
16,891,904 bytes RSS. Raw logs are in `results/` and `localrun.log`. The
compiler is the same audit build recorded in
[`c06j probe evidence`](../ieee1800-audit-c06j-20261020/README.md).

## Issue dedupe

`dedupe-searches.sh` searches GitHub open and closed issues; full output is in
[`dedupe-results.txt`](dedupe-results.txt). It found no existing §10.5 issue.
Related search hits are different behavior:

- #715 concerns declaration assignments in assertion-variable declarations.
- #752 concerns the required diagnostic for initialized static variables
  without an explicit lifetime (§6.21).
- Closed #101 concerns a class copy-constructor declaration initializer.

No issue was filed because this probe found no gap. The lead helper still
returns `daily lead cap reached (80)` despite the reported 9/80 allowance, so
matrix classification remains `PROBED — LEAD PENDING`.
