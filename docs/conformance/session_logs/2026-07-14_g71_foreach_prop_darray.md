# Session 2026-07-14k — G71: foreach over class-property dynamic arrays silently iterated zero times (M4 tail)

## Context: milestone close-out audit

This session's directive was to close out the earlier milestones (M1-M7)
before continuing M8 increment 2 and opening M9. A re-probe audit of the
recorded milestone tails established:

- **M3 tail** (constraint solver): dynamic-array foreach constraints
  still warned-and-ignored (elements unconstrained); non-0-based static
  foreach ranges still warned-and-ignored. `solve a before b` with an
  `a -> b == K` implication now shows a correct ~50/50 distribution on
  `a` and zero implication violations over 200 draws (the xor-diversity
  objective covers this shape; staged ordering itself remains
  unimplemented).
- **M4 tail** (container runtime): G35 (`u.reverse()` on unpacked),
  G36 (`u.sort()` on unpacked), G40 (`unique()` on unpacked) are still
  compile-progress no-ops (warning + wrong data). **G38 `string.putc`
  and G39 `new[N](old)` resize-copy now PASS** (fixed by prior work;
  audit entries stale).
- **M5** (interfaces/modports): G26 (`import` task in modport) still
  hard `sorry`; blocks the combined interface probe.
- **M6**: complete (hygiene deferral recorded). **M7**: UVM canonical
  regression green as of the last checkpoint.
- **NEW G71** found while probing M3: `foreach (c.da[i])` over a
  class-property plain dynamic array compiles WITHOUT DIAGNOSTIC and
  iterates ZERO times — a fully silent miscompile (worse than the
  warned M3/M4 tails), and the reason the M3 dynforeach probe
  false-passed (its checking loop never ran).

Selected target (manifesto principle 4 — eliminate silent miscompiles
first): **G71**, the foreach/element-access family over class-property
plain dynamic arrays.

## Root cause (three layers)

IEEE 1800-2017 12.7.3 (foreach), 7.5 (dynamic arrays are 0-based).

1. **Elaboration**: `PForeach::elaborate_runtime_array_` lowered plain
   darray foreach bounds as `$low(arr)`/`$high(arr)`. For a
   class-property receiver, `get_array_info()` (eval_tree.cc) has no
   `NetEProperty` case, so `$high(<property>)` constant-folded to `'x'`
   at elaboration and the loop condition was never true — zero
   iterations, no diagnostic. (Queues used a `0 <= i < size` loop with
   `$ivl_queue_method$size`, which supports property receivers — which
   is why queue and assoc properties worked.)
2. **Codegen, object context**: once the loop ran, the nested descent
   (`foreach (dd[i,j])`, and any `dd[i]` used as a container) crashed:
   `eval_object_select`/`eval_object_property` routed indexed
   plain-darray properties down the arrayed-property path
   (`%prop/obj pidx, idx_word`), consuming the ELEMENT index as the
   property-ARRAY index → `property_object::get_object` assertion
   `idx < array_size_` (array_size_ is 1 for a scalar property).
   The compensating "index means element access" branches existed only
   for queue and assoc properties (and for darrays only in the vec4
   drawer).
3. **Codegen, vec4/string/real contexts**: `draw_select_vec4` asserted
   on chained selects rooted at darray properties
   (`ivl_expr_signal(PROPERTY)` yields the CLASS-typed handle signal →
   data-type assertion abort), and the string/real property drawers
   lacked the darray-indexed arm entirely (string-element reads
   returned "" silently).

## Implementation

- **elaborate.cc** (`PForeach::elaborate_runtime_array_`): queues AND
  plain dynamic arrays now both use the `0 <= idx < size` loop
  (both are 0-based per 7.5/7.10); the size sfunc accepts signal and
  non-signal receivers. The `$low/$high` VPI path remains only for
  types that need declared ranges.
- **tgt-vvp/vvp_priv.h**: new `expr_is_dynarray_container_()`
  (queue OR plain darray).
- **tgt-vvp/eval_object.c**: `eval_object_select` — non-signal
  dynarray containers (property, chained select) load the container
  object and index within it (`%load/qo/obj`) instead of falling into
  the arrayed-property path; `eval_object_property` — indexed
  plain-darray properties treated like indexed queue properties.
- **tgt-vvp/eval_vec4.c**: `draw_select_vec4` — the non-signal
  container branch now accepts plain darrays (was queue-only; darrays
  fell into the signal-only branch and hit the data-type assertion).
- **tgt-vvp/eval_string.c / eval_real.c**: property drawers gained the
  darray-indexed arm (element access via `%load/qo/str` / `%load/qo/r`).
- **vvp/vthread.cc**: `load_qo<>` accepts any `vvp_darray` receiver
  (was `vvp_queue`-only). The typed `get_word` overloads are virtual on
  the `vvp_darray` base, so dispatch is unchanged for queues, and plain
  darray objects now serve `%load/qo/*`. Wrong-element-kind receivers
  keep the default-value (out-of-bounds) semantics.

No UVM-specific branches; all changes are general container/codegen
paths.

## What now works (pinned by tests/g71_foreach_prop_darray_test.sv)

- `foreach` over class-property plain darrays: this-receiver and
  external-receiver, with element reads AND writes in the body.
- Nested two-index `foreach (dd[i,j])` over jagged darray-of-darray
  properties (counts and element reads).
- Chained positional element reads `c.dd[i][j]` in assignment/operand
  context (previously: ivl assertion abort).
- String-element darray property reads and comparisons
  (`c.sda[i] == "ab"`; previously silently "").
- Queue/assoc property foreach pinned as characterization (were
  already correct).

## Known remaining tails (recorded, out of this checkpoint's scope)

- Chained element STORES through plain-darray outers
  (`c.dd[i][j] = v` silently no-ops; `dd_sig[i][j] = v` likewise) —
  the G09 store2 rewrite covers queue-typed outers only. Next natural
  increment: extend the `$ivl_assoc$store2` rewrite + lowering to
  darray outers and property outers.
- Display-context chained reads (`$display("%0d", c.dd[0][1])`) draw
  in object context and print null — G09 "object-valued chained reads"
  tail.
- `$size/$high/$low/$dimensions` on property-darray receivers still
  constant-fold to 'x' (`get_array_info` has no property case) — same
  defect family as layer 1; foreach no longer depends on it.
- Method calls on indexed elements (`c.sda[i].len()`) — G70 family.
- foreach over a class-property STRING still elaborates the body
  without a loop (pre-existing compile-progress path, now one of the
  few remaining silent shapes in this family).

## Regressions

(Recorded in the checkpoint commit message: UVM canonical suite,
ivtest vvp_reg.pl patched-vs-pristine failure-name diff, negative
suite 9/9, m6 region trace PASS, focused g09/g10/m3/m6 suites PASS.)

## Checkpoint 2 — M3 tail: non-0-based foreach constraint ranges

IEEE 1800-2017 18.5.8.1: the foreach loop variable ranges over the
array's DECLARED indices. The constraint unroller
(`pexpr_to_constraint_ir`, elaborate.cc) rejected any static rand
array whose declared range had two nonzero bounds (`arr[3:1]`,
`arr[5:2]`) — the whole item was warned-and-ignored and the elements
were left unconstrained — and bound the loop variable to the CANONICAL
0-based position (correct only for the previously-supported 0-based
shapes).

Fix (elaborate.cc, both sites):
- the foreach unroll binds the loop variable to the declared index
  values (`range_lo + i`, uint64 two's-complement so negative bounds
  stay consistent with the solver's constant folding);
- the element-variable emitter maps declared -> canonical
  (`elem -= range_lo`, bounds-checked) since the solver/write-back
  element slots (`e:N:W:I`) are canonical property-array positions.

Test: `tests/m3_constraint_nonzero_range_test.sv` ([3:1] equality,
[5:2] inside-ranges with index arithmetic, 0-based characterization).
Focused m3 suites (array/signed/semantics) re-run PASS under the fix.

Remaining M3 tail after this: dynamic-array foreach constraints
(runtime expansion + staged size-then-elements solve) and
solve...before staged ordering.

## M-audit snapshot for the milestone close-out plan

- M1: minor recorded tails only (multi-hop statement chains).
- M2: complete for probed shapes; dynamic `uvm_field_array_*` unprobed.
- M3: OPEN — dynamic-array foreach constraints; non-0-based foreach
  ranges; solve...before staged ordering (distribution OK for the
  common implication shape).
- M4: OPEN — G35/G36/G40 (ordering/manipulation methods on unpacked
  fixed-size arrays); container store/read chain tails above. G38/G39
  verified fixed (audit updated).
- M5: OPEN — G26-G29 all still fail (modport import ports, implicit
  modport bind, interface arrays, b.mst instance-modport bind).
- M6: complete. M7: green. M8: increment 1 merged; increment 2 (real
  clocking semantics) pending. M9: not started.
