# 2026-07-17 — M9B/M9C: intersect, until family, within

Directive: "Implement M9C and M9B" — close the loud-sorry SVA operators
flagged by the truth audit (`intersect` for M9B; `within` and the
`until` family for M9C; `throughout` was done earlier).

## Engine context

The concurrent-assertion engine (`pform_make_assertion`) lowers a linear
sequence chain (`std::vector<sva_seq_step_t>`) to a synthesized clocked
checker built from a token pipeline + optional final window/unbounded
region, with `$past`/`$rose`/… expanded by `sva_rewrite_sampled_` into
explicit history registers. It handles one linear chain per property.

Two of the new operators fit that model by source-level transformation;
the other two need per-cycle machinery the linear chain cannot express,
so they get a dedicated lowering.

## M9B — intersect (16.9.6)

`s1 intersect s2` matches over an interval iff both match over exactly
that interval (same start and end) → equal length required. New helper
`sva_expand_fixed_` expands a fixed-length sequence into a per-cycle
boolean array (gap cycles = null). `pform_sva_intersect` expands both,
requires equal length, and emits a single unit-delay chain whose cycle-k
boolean is `a[k] && b[k]` (dropping redundant `&&1`), fed to the normal
op_type-0 path. Unequal fixed lengths can never match and variable-
length operands are unsupported — both loud, spec-cited sorries rather
than a silent always-false checker. **M9B COMPLETE** (and/or already
worked).

## M9C — until family (16.12.10)

`until`/`until_with` and strong `s_until`/`s_until_with`, boolean
operands. Under overlapping-attempt semantics (a fresh attempt every
clock) the aggregate obligation collapses to a per-cycle boolean check:

- `until`      — fail at any cycle with `!p && !q`
- `until_with` — fail at any cycle with `!p` (q irrelevant)

The strong forms add a liveness obligation: q must eventually hold. A
`pend` flag (set when p opens an unreleased attempt, cleared when q
holds) that survives to end-of-simulation is a strong failure, reported
from a synthesized `final` block.

## M9C — within (16.9.6)

`s1 within s2`, fixed-length, len(s1) ≤ len(s2). Both operands expand to
per-cycle boolean arrays; the match at the window end (now) is one
combinational indicator over `$past` samples:

    wmatch = (AND over s2 cycles: past(B[p], L2-p))
             && (OR over offsets j: AND over s1 cycles: past(A[i], L2-(j+i)))

A `$past(1'b1, L2)` warm-up guard is 0 until L2 cycles elapse, so windows
predating time 0 raise no obligation. cover counts `wmatch`; assert fails
on `valid && !wmatch`. Reuses `sva_rewrite_sampled_` to build the `$past`
history chains.

Both until and within are stashed on `sva_property_t` with dedicated
op_types (4–8) and lowered by the new `pform_make_temporal_assertion_`,
dispatched from `pform_make_assertion` once `kind` is known.

## Scope and honest sorries

Everything is scoped to fixed-length (intersect/within) or boolean
(until) operands, with loud, IEEE-cited sorries for the variable-length,
unequal-length, and sequence-operand shapes — no silent miscompiles. The
liveness operators `nexttime`/`eventually`/`s_eventually` remain loud
sorries (need an unbounded-obligation model) → M9C-live.

## Verification

- `tests/m9b_intersect_test.sv` — length-1 and length-2 intersect, with
  an s1-matches / s2-fails discriminator; exact match counts.
- `tests/m9c_until_test.sv` — all four operators on one p/q profile with
  distinct hand-derived fail counts (until 1, until_with 3, and the
  strong forms equal when q arrives).
- `tests/m9c_until_live_test.sv` — strong liveness: p high, q never; weak
  path stays silent, the FINAL `$error` fires (isolates liveness).
- `tests/m9c_within_test.sv` — s2 all-ones, s1 a boolean → "b present in
  each 3-cycle window", exercising the 3-offset disjunction + warm-up
  guard; exact fail count (3).
- Negative: `m9b_intersect_unequal_len`, `m9b_intersect_variable_len`,
  `m9c_until_sequence_operand`, `m9c_within_left_longer`.

Regression gates: **UVM 173/173** (169 + 4 new, zero no-check, zero
fail); **ivtest baseline-identical** (99 fails, name-diff identical);
**negative 28/28**.

## Status

**M9B COMPLETE. M9C** now covers `throughout`, `intersect`, `within`,
and the full `until` family; the `nexttime`/`eventually`/`s_eventually`
liveness operators remain the only loud SVA sorries.

Commit: `sva: implement intersect, until family, and within (M9B/M9C)`.
