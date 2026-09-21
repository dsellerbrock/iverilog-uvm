# September 20 PR review and repairs

Merged main revision: `0991f15d338f73137b416af46f6ca664a74a3d03`
(PRs 301 and 303). Post-merge CI remains pending at this checkpoint.
The local integration `0133287ec` additionally contains unmerged PRs 302,
304 and 305 and is **not qualified**.

Review reproduced three blockers in both IEEE 1800-2017 and 2023 modes:

- PR302: a function used as a fixed-array foreach selector was never called.
- PR304: range-bin cross-with selection was discarded after a warning;
  coverage was 91.666667 rather than the required 100 percent.
- PR305: an undeclared selector was accepted when the body did not use it.
  A real-valued selector was also accepted.

Evidence and original compiler fingerprint:
`evidence/review-20260920/baseline-review.json` and adjacent reducers/logs.
The original five PR positives passed in both editions; those positive
checks did not cover these defects.

The selected repair scope and pending gates are maintained in
[ACTIVE_WORK](../../../.ai/ACTIVE_WORK.yaml) and
[CAMPAIGN](../../../.ai/CAMPAIGN.yaml). This record does not qualify the
combined baseline or claim all recursive cross-with grammar implemented.

The September 18 OpenTitan census uses clean Earlgrey-PROD-M6 sources and
compiler fingerprint `545fb8c1ebcd206ff20b4df293e19305b6ae2225750a32c8603801634af4d714`.
Its xbar runtime processed 256 scoreboard items but ended with
`TEST FAILED CHECKS`; process exit zero is not a test pass. That run does
not supersede the separately labeled earlier patched-release pass.

The original local OpenTitan adapter patch is retained in the named git
stash and `evidence/review-20260920/preserved-opentitan-matrix.patch`.
No OpenTitan or Caliptra sources were changed during this review.

## Local repair evidence

The working-tree repairs now validate constraint selector names and types,
evaluate fixed-array procedural selectors once on loop entry, and evaluate
cross-with predicates over distinct value tuples from static range bins.
The coverage implementation preserves coverpoint width and signedness and
uses the existing 65,536 limit as a separate per-bin-tuple value-product
bound. Larger products and unsupported with-predicate source bins produce
compilation errors, not fabricated topology. Recursive inner `with` and
explicit `matches` are not claimed by this patch.

Raw paired-edition checks: `evidence/review-20260920/selector-repairs-results.json`
and `cross-repairs-results.json`. Both selector harnesses passed in
`selector-focus-gate.log`. The coverage legacy and JSON gates each pass six edition-specific tests
in `coverage-focus-gate.log`; 112 existing foreach/cross legacy neighbors
pass in `neighbors-legacy.log`. No broad qualification or
new PR merge is established by these focused results.
