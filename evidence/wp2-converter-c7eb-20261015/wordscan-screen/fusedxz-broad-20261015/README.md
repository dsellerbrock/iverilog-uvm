# Fused X/Z scan broad Callgrind screen

Pinned measurement base: `c7ebca768c21c251d9c165c9aff0e363768030b1`.

This screen checks instruction counts and exact outputs for the same 18
sim-hotspots workloads used by the word-plane screen. Core, vector, and mixed
groups run as a three-task Slurm array; the FST workload uses
`--fair-sched=yes` for both sides because default Callgrind crashed a reference
worker thread on the earlier attempt. Each task gets 2 CPUs, 8 GiB, and a
2-hour limit. Inputs, source runner, reference install, candidate install,
profiles, and outputs are independently pinned and hashed.

Attempt 1379 exited before measurements because the wrapper omitted the
explicit UVM DPI plugin path required by the copied benchmark runner. No
workload was measured. This harness setup failure is preserved here; the
fresh retry records `UVM_DPI` explicitly.

The fused scan then completed the full 18-workload Callgrind corpus on this
pinned base. Job 1383 tasks 0 and 1 measured core and vector; job 1388 measured
the mixed group with FST fair scheduling. All 18 rows report output identity
and successful profiles. Instruction deltas range from -0.026238%
(`strings_aa_queue`) to +0.002218% (`uvm_config_factory`). Jobs 1396 and 1405
compiled and ran edge tests on both installs; job 1405 adds signed 65-bit
tail-word coverage and prints the regression runner's required `PASSED` line.
Wide/narrow X/Z, overflow, and sign-extension cases pass with matching
stdout and stderr. The
aggregate is a clean screen, not a strict comparison against the earlier
word-plane variant: the focused follow-up adds a narrow-Z assertion. The local
archive retains per-attempt details; this PR keeps the aggregate result and
compact report.

The combined table is [`instruction-counts-18.csv`](instruction-counts-18.csv).
The candidate patch used by the matched follow-up has SHA-256
`0306764c76587f0ac71c30fe05bf7c0f132e8911868bf8121398b347c7acee6f`.
This PR retains the combined count table and experiment report. Raw Callgrind
profiles, duplicate outputs, and build trees are kept in the local
revision-scoped evidence archive and are omitted from the PR.
