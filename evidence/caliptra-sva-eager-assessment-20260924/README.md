# Caliptra assertion-function assessment (2026-09-24)

This is a read-only classification of the existing
[`eager_consequent.sv`](../caliptra-post-aes-sva-triage-20260923/eager_consequent.sv)
RED. It does not change Icarus or pinned Caliptra and does not qualify an L0
test. The installed compiler, elaborator, and runtime SHA256 values were
`1590b064aee694d390f8e18b1ca3469a5a47405397db9b8e385b6c5b41f1a5a2`,
`9bc1d92310c3e5469b9906e016ff88f2ce3e2e4ed02183cd4132d9cc43cfdaa5`,
and `e9b7a64a8643973c9bc6597ca604285bbd718cf733e45181f6155390d9fdc8c6`.

## Semantic result

[IEEE 1800-2017](https://rfsoc.mit.edu/6S965/_static/F25/documentation/1800-2017.pdf)
and [IEEE 1800-2023](https://www.iccircle.com/static/upload/img20240319175450.pdf)
§16.6 require functions in concurrent-assertion Boolean expressions to be
automatic (or stateless) **and free of side effects**. Section 16.12.7 says
an implication with no antecedent match succeeds vacuously and its consequent
is evaluated for each antecedent match; `|=>` starts a nonempty consequent on
the next assertion clock. Section 16.5.1 uses sampled argument values for an
assertion function call. These requirements agree in the two editions for
this case.

The pinned Caliptra `caliptra_top_sva.sv` at source revision
`49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e` calls `$display` **inside**
`check_all_kv_debug_values()` at lines 208-223 and
`check_mldsa_signature()` at lines 717-764. Their calls appear as `|=>`
consequents at lines 225-236 and 791-797. The SK and PK checker functions
use the same pattern. These functions violate §16.6's side-effect rule, so
their extra `SVA ERROR` prints cannot establish a standards-conformance
failure in the execution of a legal property. In the exact unsafe first-case
log, the first detailed post-reset KV print is line 116; signature follows at
line 119. This is the first *eager-checker* divergence identified here; the
log also contains earlier reset-assertion diagnostics. No corresponding outer
`KV debug flush comprehensive check failed` or `Signature verification
failed` action was found in that log. The true TLU/SOC/LSU assertion actions
later in the run and the L0 zero-error criterion remain unchanged.

The new [`sampled_pure_vs_impure.sv`](sampled_pure_vs_impure.sv) is a paired
control. One antecedent matches at 15 ns; `data` is assigned by NBA on the
25 ns consequent clock. The legal direct and pure-function consequents both
see sampled `data=0` and each fail exactly once. A deliberately illegal
function also returns that sampled value, but writes a counter and prints on
every one of five clocks, including vacuous clocks. Both 2017 and 2023 runs
exit zero with:

```text
INNER time=5000 value=0
INNER time=15000 value=0
INNER time=25000 value=0
INNER time=35000 value=1
INNER time=45000 value=1
SUMMARY direct=1 pure=1 impure=1 calls=5 data=1
```

The first unwanted call is at 5 ns, when no antecedent has matched. That is
the first observable divergence for the deliberately illegal checker; it is
not a property failure.

Run from the campaign worktree:

```sh
for edition in 2017 2023; do
  local-install/bin/iverilog -g$edition -gassertions -s sampled_pure_vs_impure \
    -o /tmp/sampled_pure_vs_impure_$edition.vvp \
    evidence/caliptra-sva-eager-assessment-20260924/sampled_pure_vs_impure.sv
  local-install/bin/vvp /tmp/sampled_pure_vs_impure_$edition.vvp
done
```

The exact outputs are [`pure_impure_2017.log`](pure_impure_2017.log) and
[`pure_impure_2023.log`](pure_impure_2023.log). The earlier reducer also
reports five calls per impure consequent but only one genuine assertion
failure for a true antecedent. No legal property-truth defect is shown.

## Owner and possible future blocker

In [`pform.cc`](../../pform.cc), `pform_make_assertion` unconditionally adds
every consequent `seq[j].expr` to the per-clock `pre` captures at lines
25993-25998. It then places `pre` before `sva_observed_wait_` and the
disable/obligation logic at lines 26437-26447. The generated VVP accordingly
calls the function before `%wait/observed`; the runtime executes that code as
emitted. The relevant source stage is assertion lowering, not `vvp/vvp_z3.cc`
or the event scheduler. For **strict conformance**, however, the first
future blocker should be purity validation after function binding, not a
scheduler change that tries to define behavior for the illegal Caliptra
checker. An existing function purity walker in `elaborate.cc`
(`constraint_function_purity_t`) may be reusable after checking its distinct
constraint semantics.

Proposed separate blocker, if selected: reject direct `$display`/external
state writes and transitive impure helper calls used as concurrent-assertion
Boolean expressions, with a clear per-call diagnostic in both editions.
Positive controls must retain automatic pure functions with sampled
arguments, false and true antecedents, next-clock NBA behavior, and legal
logging in an assertion action block. Unknown calls must not be silently
accepted as pure. This changes strict compilation of the pinned Caliptra
testbench and therefore requires a separate campaign decision; it is not a
way to turn the current nonstandard L0 run into a pass.
