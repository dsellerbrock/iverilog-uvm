# Proposal: fast required pull request tier

## Proposal

Require a small Linux smoke tier for pull requests, then run the complete Linux, macOS, and Windows matrix after merge and on manual dispatch. Keep the full matrix available for pre-merge validation when a change needs platform-specific coverage.

Recommend moving macOS and Windows to the post-merge/nightly tier. If they must remain pre-merge, split the macOS workflow so no job approaches GitHub's six-hour job limit.

The smoke candidate covers 55 named SystemVerilog regressions, all 14 standalone root reproducers, VPI, runtime, and negative tests through `ci/run-smoke.sh`. Measure its clean runtime before setting a timeout or promising a merge-time target.

## Evidence

Across the 12 failed main pushes from October 1–8, 10 had test/gate failures on both Linux lanes, one Linux run was terminated by runner shutdown, and one failed only on CLANG64 and MINGW64 (its logs are no longer available). The 20 cancellations on October 9–10 were concentrated in two merge bursts (19 pushes and one workflow dispatch).

Median completed job durations across those 12 pushes were 35.9 minutes on Ubuntu 24.04 (n=12), 39.2 minutes on Ubuntu 22.04 (n=12), 155.4 minutes on CLANG64 (n=10), 155.4 minutes on MINGW64 (n=10), 158.0 minutes on UCRT64 (n=10), and 265.8 minutes on macOS (n=10).

On October 12, the main GitHub run for `9cfce137` was cancelled at the six-hour job limit during macOS UVM front-end regression; the other five lanes passed. This shows that a single per-pull-request macOS job can consume the full hosted-runner limit before reaching a verdict.

## Tradeoff

This shortens the default PR feedback path but moves some macOS and Windows failures to post-merge detection. Keep a manual full-matrix path and have the nightly Slurm gate cover the main branch. Splitting the macOS workload preserves pre-merge coverage but adds workflow complexity and still leaves a multi-hour gate.

## Status

Proposal only. No workflow or repository setting is changed here.
