# OpenTitan HMAC Boolean `dist` subject (2026-08-24)

## Frontier and exact source

After the VVP concat first-delivery gate removed HMAC's time-zero `RspZero_A`,
the unchanged image stopped in the constraint solver with:

```text
Error: operator is applied to arguments of the wrong sort
```

`IVL_Z3_SOLVE_TRACE=1` localized it to `hmac_smoke_vseq.digest_size_c`.
The emitted constraint IR was:

```text
(dist (eq (countones p:79:4) c:1:32:s)
      (b c:4:32:s c:1:32:s)
      (b c:1:32:s c:0:32:s))
```

This comes directly from unmodified OpenTitan
`hw/ip/hmac/dv/env/seq_lib/hmac_base_vseq.sv`:

```systemverilog
$countones(digest_size) == 1 dist {
  1 :/ 4,
  0 :/ 1
};
```

No OpenTitan source was changed.

IEEE 1800-2023 Annex A defines `expression_or_dist` as `expression [ dist {
dist_list } ]`; the subject is the complete preceding expression, so the
unparenthesized OpenTitan spelling is legal. Slang 11.0.448 rejects that exact
spelling as an `int`/`void` binary operation but accepts a parenthesized
equivalent. This is recorded as a reference-tool parser disagreement, not as a
reason to rewrite the OpenTitan source or weaken the permanent regression.

## Root cause and implementation

SystemVerilog relational/logical results are one-bit integral values. Z3 uses
a distinct Bool sort for them. The solver's ordinary expression paths already
had a `bool_to_bv1` bridge, but `dist` passed its subject directly to bitvector
coercion and equality/range operators. A Boolean subject therefore met a
bitvector branch constant and Z3 rejected the malformed operation.

The subject is now converted to a one-bit bitvector before its SystemVerilog
width and signedness are captured. The parser also records every solver leaf
referenced by an unguarded `dist` subject, including dynamic-foreach elements.
If at least one leaf is active, the existing exact weighted sampler may pin an
integral expression to its selected branch before the general diversity pass
chooses a model within that branch. Candidate comparisons retain the branch
literal's width; an impossible value such as 2 cannot truncate into a one-bit
Boolean value and inherit its weight. The old expression-subject fallback used
weighted soft assertions, which optimized for the heavier feasible branch
rather than sampling with the specified probability. Guarded distributions
retain their guarded hard clauses and weighted-soft fallback and are outside
this exact-sampling claim. Multiple distributions over the same subject retain
their pre-existing declaration-order-dependent approximation and are likewise
not claimed exact.

Arithmetic solver ASTs may carry physical carry/product headroom beyond their
SystemVerilog self-determined width. Exact candidate coercion uses that
physical sort width, matching the hard branch and avoiding a wrong-sort pin
for subjects such as `a + b`.

The same audit exposed a pre-existing IEEE 1800-2023 18.5.3 range-weight
defect. Although the parser retained whether a source item used `:=` or `:/`,
constraint IR dropped that mode and the runtime treated every range as `:/`.
It also flattened range members into weighted candidates before checking
joint feasibility. That incorrectly reduced a `:=` range's aggregate weight
when another constraint excluded members; the standard defines that aggregate
as `specified_weight * complete_source_span` even when only one member remains
feasible.

New IR emits `(b := W item)` or `(b :/ W item)`. The runtime still accepts an
old `(b W item)` branch and gives an unmarked range its historical `:/`
interpretation. For exact ranges, the solver first records every feasible
member, selects an item by its aggregate weight, and then chooses uniformly
among that item's feasible members. Overlapping items remain separate choices,
so their contributions to a shared value are additive. Range endpoints retain
their typed width/sign metadata. Hard comparisons, normalized coordinates, and
exact pins all use the same IEEE 11.8.1 comparison context; this covers signed
ranges crossing zero, narrow signed literals, unsigned operands on a signed
subject, and open subject-domain endpoints. Signed constant occurrences use
fresh aliases constrained to their raw bits, so Z3 numeral hash-consing cannot
leak signedness into an unsigned occurrence.

The bounded accepted subset now includes the actual OpenTitan terminal,
comparison, `$countones`, unary bitwise-not, bit/part-select, concatenation,
and arithmetic subject shapes found by the source audit. Arithmetic lowering
propagates the common width and signedness through nested add, subtract,
multiply, divide, modulus, and the supported unary forms, applying the
SystemVerilog result-width truncation before a surrounding operation. This is
what preserves such source forms as `100-(a+b)`, `(100-a-b)/2`, and
`9*max/10`. Ground item, endpoint, and weight folding additionally handles
typed fill literals, ternaries, power, shifts, xor, and integral repeat
concatenations whose total width is at most 64 bits, including the OTP-shaped
`{OTP_ADDR_WIDTH{1'b1}}`. Signed/unsigned ring operations are accepted only
when the compact IR can preserve every intermediate width and comparison
context; otherwise the source follows the documented loud diagnostic or
weighted-soft fallback rather than a lossy exact path.

Exact expansion is capped at 256
members. A larger range emits a one-time warning and retains the hard-union plus
weighted-soft fallback. Weights are folded at their SystemVerilog semantic
width, so overflow wraps before the distribution sees the value. A weight over
`UINT_MAX` likewise warns and selects the fallback rather than silently
clamping an alleged exact ratio. Exact item aggregates use checked `uint64_t`
accounting, so a `:=` span can legitimately take the total above 2^32. Item
selection draws an unbiased 64-bit bounded ticket from two object-RNG words
using rejection over a complete set of residue classes; it no longer scales a
single 32-bit word through floating point. An aggregate overflow also falls
back with a bounded warning.

Distribution groups are no longer installed globally before solve-before
staging. An exact group is sampled when the maximum ordering rank of its active
subject leaves becomes due; only a due fallback group participates in that
stage's fresh optimizer. This prevents a heavier soft branch from pinning an
early-ranked subject before its exact draw. A distribution nested in `soft`
also retains that outer preference's complete disable ownership, while an
ordinary hard distribution remains unaffected by `disable soft`. Guarded,
nonground, mixed-order, and over-cap
distributions retain the fallback. A source literal or resolved constant in a
dist subject, item, endpoint, or weight with nonzero or unknown bits above bit
63 is a compile-time error because the textual IR cannot preserve it; a wider
value whose high bits are all zero remains representable when no runtime
storage leaf is wider than 64 bits. A wide ground weight that fits uint64 is
evaluated normally. A result above uint64 warns and remains nonzero;
the fallback saturates only the host-sized soft objective rather than dropping
the branch as an unevaluated weight.
Scope `std::randomize` continues to use the same weighted-soft
path and is not included in the exact class-sampling claim.

## Permanent reducer and replay

`sv_constraint_dist_boolean_subject` copies the HMAC expression and 4:1
weights. Against the post-PR-231 runtime before this fix it exits 1 with the
same Z3 sort error. With the fix, 100 deterministic HMAC-shaped draws produce
both Boolean branches with the heavier branch dominant. The same test proves
that widened and nested arithmetic takes legal branches without a Z3 sort
error. It pins signed/mixed addition, multiplication, subtraction, division,
modulus, common-width truncation, ground power/shift/xor/ternary expressions,
fill and repeat-concatenation endpoints, bit/part/concat subjects, terminal
comparisons, and the OpenTitan MUBI/EDN/SPI weight shapes.
It also distinguishes explicit/default `:=` ranges from `:/`, proves a pruned
`:=` range keeps its full-span aggregate, and checks additive overlapping
items, signed crossing/open ranges, signed/mixed addition subjects,
mixed signedness and width, zero-weight
overlap, solve-before staging, outer-soft disable ownership, semantic-width
weight wrapping, and the exact-support fallback bounds. A seeded equal-weight
case with an aggregate above 2^32 pins use of the two-word integer-ticket path:
the new path produces `16'h97a5`, while the removed one-word path produced
`16'h60d9`. This is a path/replay control; the absence of sampler bias follows
from the rejection algorithm, not from sixteen statistical samples. Both
permanent harnesses report `PASSED`; the fallback boundary cases emit their
four expected one-time warnings (range cap, nonground item, over-`UINT_MAX`,
and over-uint64 result).
`sv_constraint_dist_wide_literal_fail` separately pins the compile-time lossy
literal/resolved-constant, wider runtime-storage, and expression-context
boundaries. Its inline `std::randomize` case also proves caller `v:` slots use
their actual width and signedness during `dist` validation rather than the
temporary 32-bit token spelling used while the constraint is first walked.

## OpenTitan source-audit boundary

The exhaustive source scan found 714 direct `.sv` `dist` keyword locations
(712 same-line and two split across lines). This batch supports 579 and leaves
135 legitimate locations loud for later lowering work. Of those residuals,
117 use Flash indexed-member subjects, ten use AC indexed-member subjects, one
uses an AC dynamic-index endpoint, two use OTP `PartInfo[index].offset`
aggregate endpoints, and two use riscv-dv package-array items. The remaining
three are 77-bit Darjeeling alert-handler fill/range expressions; the compact
IR and runtime value-transfer path currently support at most 64-bit storage
leaves. Seventy-two indexed Flash weight expressions occur within 36 of the
already-counted Flash subject sites and do not increase the total. Two
additional supported `.svh` macro bodies have ten wrapper use sites. Because
preprocessing and target selection control which macro/configuration sites
elaborate together, these are source metrics rather than a claimed single
elaborated-node count.

A VVP image compiled before the mode marker was added remains a compatibility
control. With its fixed seed and 512 draws, the unmarked `[0:3]` range versus a
scalar of weight 4 currently produces 94:418, inside a broad semantic threshold
for the historical `:/` interpretation and far from `:=`'s approximately equal
aggregate weights. The gate deliberately checks the semantic band rather than
pinning an implementation-specific exact random sequence.

`tests/vvp_runtime/run_dist_ir_compat.sh` makes that legacy check permanent and
also injects one extra top-level close delimiter into the raw constraint IR.
The malformed image terminates with the same samples and one bounded recovery
warning instead of leaving the parser on an unchanging cursor.

The unchanged HMAC source list was freshly recompiled with this compiler and
the arm64 `cryptoc_dpi` module rebuilt from its generated DPI-export stubs.
Compilation exits zero and the smoke advances from time zero to 3,637,253 ps.
Neither `RspZero_A`, `BUILDERR`, nor the Z3 sort error reappears. The next
independent frontier is a scoreboard mismatch at
`hmac_scoreboard.sv:1059`: `cfg.hmac_vif.is_idle()` is 0 while the expected
value is 1. The mismatch has been reduced to the separate itemless
clocking-block event path. UVM records one error and the authoritative `TEST
FAILED CHECKS` banner, so the process's `$finish` exit status is not treated as
a pass.
