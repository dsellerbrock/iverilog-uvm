# Proposal: fast required pull request tier

## Proposal

Require a small Linux smoke tier for pull requests, then run the complete Linux, macOS, and Windows matrix after merge and on manual dispatch. Keep the full matrix available for pre-merge validation when a change needs platform-specific coverage.

The smoke candidate covers 55 named SystemVerilog regressions, all 14 standalone root reproducers, VPI, runtime, and negative tests through `ci/run-smoke.sh`. Measure its clean runtime before setting a timeout or promising a merge-time target.

## Evidence

The October 1–10 history contains long full-matrix runs: median execution was about 36–39 minutes on Linux and 155–265 minutes on the other platform lanes. Nine of ten classifiable functional failures appeared on Linux; one was Windows-only and its logs expired.

## Tradeoff

This shortens the default PR feedback path but moves some macOS and Windows failures to post-merge detection. Keep a manual full-matrix path and have the nightly Slurm gate cover the main branch.

## Status

Proposal only. No workflow or repository setting is changed here.
