# L56 — Dynamic packed-prefix write bounds

IEEE 1800-2017 and IEEE 1800-2023 are checked separately. The applicable
packed select semantics are in 11.5.1/11.5.2 and 7.4.6. Invalid leading
indices must not alias another element; a partial final select may update
only the bits within its enclosing packed dimension.

The assignment IR now retains a checked dynamic carrier separately from the
relative final select. Existing checked-index evaluation validates each raw
index before canonicalization, preserving signedness, wide values, X/Z, and
ascending declarations. VVP clips the actual partial store, including delayed
NBA events, without replacing neighboring bits. Compound reads use nested
carrier and final selects so unavailable old-value bits retain the correct
four-state/two-state behavior. Fixed unpacked words retain an independent
word address and validity. Constant evaluation, synthesis, input/output
analysis, driver checks, target export, and stub inspection consume the new
metadata. VHDL and vlog95 retain explicit unsupported diagnostics.

Final review found and corrected wide synthesis operand-width assertions,
constant array part-selects mistakenly treated as bits, skipped selector
side effects on constant-invalid compound array words, and nonleaf packed
part-selects crossing enclosing element boundaries. These were corrected
before integration, not accepted as residual behavior.

## Focused evidence

Evidence root: `evidence/dynamic-mixed-driver-assessment/l56/`.

- `root-corrected-review-results.json`: 32/32 paired runs, including wide
  signed/unsigned ordinary and synthesized writes across descending,
  ascending, and negative ranges; constant part tails; invalid constant
  word side effects; and the independent 108-case nonleaf matrix.
- `root-corrected-regression-results.json`: 18/18 paired runs. These include
  the 378-case packed, 108-case bit/whole-element, and 504-case fixed-array
  matrices, compound old-value arithmetic, delayed NBA capture, sensitivity,
  and dynamic/static/compound constant-function fixtures.
- `root-neighbors-results.json`: 11/11 legacy and 19/19 JSON neighbor checks,
  including mixed-driver rejection and checked class-property index controls.
- Final permanent focused harnesses pass 5/5 legacy and 10/10 JSON:
  `final-tightened-legacy-3.log` and `final-tightened-json-3.log`, both status 0.
  They pin exact wide synthesis values, constant array part writes, and
  selector side effects on constant-invalid compound array words.

The compiler, VVP target, and runtime hashes were stable across each root
replay. Installed compiler SHA-256: `54e6d71e3cf32e99b9c50b9f62e32601ec345b5bd39c313c55fcdd4b42465875`.

## Limits and batch policy

This is focused feature validation, not a full-suite conformance claim.
The last broad-qualified semantic baseline remains `c686a4781`. L53, L54,
and L55 are already focused-validated; L56 is the fourth item, integrated
into local main at `e9531fbfb`. Full suites remain deferred until approximately
ten features under the user's batching policy.

Dynamic mixed-driver prefixes remain conservatively rejected. Existing
runtime clocking-output restrictions remain explicit. DD-025, isolated
postincrement-expression constant evaluation, remains open; its blocked
side-effect probe is not counted as passing. No application sources were
changed, no remote action was taken, and no new worktree was created.
