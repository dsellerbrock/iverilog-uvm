# L53–L62 first batch qualification

Candidate: `6d617022d`, semantic endpoint `5dfcc959f`. All seven gates finished.
Five gates passed: JSON1971, UVM357 with realDPI and no skips, SVA NFA58,
makecheck, frontend all12 scenarios. All six installed-resource hashes restored.

Integrated gate failed: legacy5041total5032pass4fail2NI3EF. VPI108,
negative149, runtime15, copyout6, and exports66 passed. Legacy failures:
pr1830834, signed_a, sv_uarray_func_return, synth_variable_packed_lvalue.
Release matrix:8SMOKE_PASS and7COMPILE_FAIL. Older releases fail named
constraint_mode lookup;2020.3.2 fails type-parameter static method lookup.

Evidence: `evidence/batch-20260914-l53-l62/qualification/first-pass-summary.json`.
The candidate is not qualified; prior qualified baseline remains `c686a4781`.

Independent legacy diagnosis isolates stale flag4 before array-return loads,
lossless signed padding rejected by live VPI argument handling, and an incorrect
sign-extension in synthesized checked indices. Oversized-index truncation in
signed_a is an outdated oracle, requiring normative correction with a valid
index control. Small reproducers are preserved beside the qualification logs.

Release constraint lookup is not honestly fixed by a no-op: num_sequences()
inside pick_sequence needs real pre-solve function evaluation and persistent
constraint enable state. A proposed no-op was rejected and superseded by the
semantic plan in evidence/uvm-release-regression-assessment/.

Root semantic follow-up: a constraint `x == state_value()` is ignored and
randomize returns success with x32 instead of wanted3, in both editions.
Named mode toggles fail lookup. Replacing the function call with direct wanted
state makes all four paired controls pass, including disabled/reenabled and
unsatisfiable fixed-rand-value behavior. This isolates missing function lowering
rather than general constraint-state enforcement. Evidence lives under
`evidence/uvm-release-regression-assessment/semantic/`.

First repair replay: four integral/logic element-return checks and six synthesis
reductions now pass. Four real/string whole-pattern returns followed by a loop
also pass, exercising the stale-flag fix without DD-031 element-store dispatch.
Deferred strobe checks still fail on this candidate; no repair freeze yet.

Second repair candidate: ten deferred-strobe checks pass with exact values,
including true OOB selections retaining X. Six explicit-cast expressions still
produce unsupported diagnostics; that broader support is not claimed here.
Original four direct replays restore prior expectations: three print PASSED,
while pr1830834 emits only its pre-existing line22 diagnostic from the gold.
Its repaired line19 live-array path is independently covered by clean deferred
sampling tests. Permanent exact-harness validation and integration remain pending.

Legacy repairs frozen: exact originalfour plus permanentstrobe5/5, JSON2/2,
close neighbors5/5, deferred-assertion controls2/2. Final root replay22/24:
ten strobe cases, two fstrobe cases, four typed patternreturns, six synthesis
cases pass. Two fmonitor cases still report the runtime's constant-memory-word
restriction; dynamic monitor support is not claimed. Six explicitcast sampled
indices likewise remain diagnosed. Finaltarget SHA:
`48ee3f6609c7c4c1da28572388c8b0d356631eb7dcdd8fd9da55aecfd96d2b58`.
The forced-capture bypass was removed; assertion capture rules remain enforced.
