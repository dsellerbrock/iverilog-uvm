# L58 — Constant-function assignment-expression effects

Local assignment and increment/decrement expressions previously failed
constant evaluation even when the same integral scalar operations worked at
runtime. The evaluator now implements local storage mutation and expression
results: assignment returns the value converted to the destination type,
prefix returns the updated value, and postfix returns the old value.

IEEE 1800-2017 and IEEE 1800-2023 are checked independently against
11.3, 11.4.1, 11.4.2, and 13.4.3. Integral compound arithmetic reuses the
existing assignment evaluator. Destination width, signedness, and two-state
conversion remain explicit; integral and real increment/decrement preserve
their required values. Uninitialized locals receive their typed defaults.
Fixed-array local indices are evaluated once, with exact wide-index
validation. Evaluated invalid indices produce the typed read default and
suppress the store; evaluator failures propagate instead of becoming defaults.
Nonlocal/reference-argument constant-function calls retain rejection.

## Evidence

Evidence root: `evidence/constant-assignment-expression-assessment/`.

- Baseline: 15 scalar forms, 30/30 paired runtime controls pass and all 30
  constant invocations fail. Both evaluator routes were missing: assignment
  expressions use `NetEAssignExpr`, while inc/dec uses `NetEUnary`.
- A candidate constructed an all-ones vector instead of numeric one for
  increment. This caused reversed results and was corrected before integration.
- Final `root-reviewed-results.json`: 80/80 paired exact-outcome checks
  pass with stable compiler/target/runtime hashes, including signed shifts,
  narrow wrap, 128-bit arithmetic, four-state behavior, real inc/dec,
  short-circuit and ternary selection, typed defaults, independent calls,
  indexed locals, invalid/wide indices, and nonlocal/ref rejection. This
  unblocks L56's invalid packed-carrier selector side-effect oracle.
- Signed invalid-index postfix comparison returned 1 instead of 0 before
  the final correction. Applying the declared signedness to typed defaults
  corrects both editions. Permanent indexed-local coverage pins the result.
- Final permanent focus: legacy 4/4 and JSON 6/6; incremental build/install
  exit 0. Logs: `l58/final-signed-{build,install,legacy,json}.*`.
- Existing constant-function neighbors: 18/18 after the final code change;
  L56 packed constant controls: 6/6 before the signed-default-only correction.
- Eight root runtime invocations emit DD-027 unresolved-functor warnings
  from emitted but uncalled array-function bodies. Their constant results
  are correct; these runs do not qualify the runtime path. The permanent
  indexed-local regression uses compile-time generate assertions.

Installed compiler SHA-256:
`d745779660da40278f77fa5e5418faca6755c03bebe1d80e7b3cd841b9d21386`.
Target: `262a9e0f876718e752cac9a4d2a531a35c1c1ff542336ee8a30443eb03f9a87e`.
Runtime: `cee0a60c11c7d401646159701e2d341932a6812a4e5199fed18f6cda516d9e2f`.

## Remaining scope

Full suites remain deferred to the user's approximately-ten-feature batch.
L53–L57 are five focused items; L58 is not counted until local integration.
The last broadly qualified semantic baseline remains `c686a4781`.

DD-026 separately records missing two-state conversion in runtime assignment
expressions; ordinary statement controls pass. DD-027 separately records a
VVP crash for runtime fixed-array element increment. Correct constant
semantics do not close those runtime defects. Other l-value forms that the
existing assignment-expression elaborator explicitly rejects are not claimed
as newly supported. No application source was changed, no remote action was
taken, and the existing worker and worktree were reused.
