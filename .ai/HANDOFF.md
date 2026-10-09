# Compiler campaign handoff — 2026-10-09

## Active blocker

Issue #497: package-qualified static class calls in expression position.
The implementation branch is `agent/ieee-batch-499-495-20261009`, based on a
merge of `origin/main` at `127b887dfdc09283ab0187a2e618421dee3d5dcc` recorded
as two-parent merge commit `2d02bb1955141765b2b51b7b3112ed42ef312be5`.

## Post-merge evidence

- Guarded serial macOS ARM64 build and install succeeded.
- Bison 3.8.2: 574 shift/reduce and 1,122 reduce/reduce conflicts.
- Paired focused regressions: legacy 11/11; JSON/VVP 12/12. The focus now
  includes strict 2017 and 2023 positive and non-static expression-negative
  cases.
- No post-merge full suite or CI result is claimed. Older full-suite totals
  describe the pre-merge candidate only.

The branch contains two actual local fixes (#499 and #497). The #495 patch is
preserved in `stash@{0}`. Inspect and activate #495 next; do not open the batch
PR until five actual fixes are integrated. Keep PR #519 separate and draft.

Three checkouts remain: this active batch, the PR #519 bot branch, and the
retained shared-graph baseline. The merged #466 checkout was retired with the
required script; its branch remains. Do not touch the separate Caliptra BFM
checkout or its processes.
