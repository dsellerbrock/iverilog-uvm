# Compiler campaign handoff — 2026-10-09

## Active blocker

Issue #495: clip partially out-of-range dynamic packed class-property ranges
under IEEE 1800-2017/2023 §11.5.1. Work is on
`agent/ieee-batch-499-495-20261009`.

Latest `origin/main` (`4b3f3424c440aca6af92153b6860a7253b925234`) is merged
with two parents as `c2f2964827803539e3e8efe0ee9ae7e0593678a9`. The preserved
#495 patch is reapplied; `stash@{0}` remains intact until the commit is safely
pushed.

## Validation

- Guarded serial macOS build: pass, 60 seconds; install: pass, 5 seconds.
- Free RAM stayed at 67–68% with the 34% minimum-free guard.
- Paired focused class-property suites: legacy 18/18 and JSON/VVP 18/18.
  Both editions cover clipping, X behavior, truncation, both directions,
  blocking/compound/NBA writes, and once-only index evaluation.
- Linux full build did not complete. The first out-of-tree attempt linked the
  top-level compiler but hit host-object/VPATH failure in `ivlpp`; forced
  attempts hit read-only source regeneration and an existing `dep` directory.
  No Linux or CI pass is claimed.
- No full suite was run.

The batch has three locally verified candidate fixes (#499, #497, #495). Keep
the batch PR closed until five fixes are verified. After committing and pushing
#495, select the next open IEEE issue from the existing queue.

## PR sync bot

PR #519 was merged into main as `4b3f3424c440aca6af92153b6860a7253b925234`.
Its conflict-resolution unit test passes locally. The post-merge sync workflow
run was queued at the last check; do not repeatedly poll it.

Three checkouts remain. Keep the separate Caliptra BFM checkout and its live
processes untouched; the retained shared-graph checkout has expected untracked
`graphify-out` files.
