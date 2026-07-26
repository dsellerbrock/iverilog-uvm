# CURRENT WORK — continuation state

**What this file is.** The shortest thing a new session can read to know
where work stands and what to pick up. It is a pointer, not a log.

- **What is left, and in what order** → `ROADMAP.md`. That is the single
  living tracker; this file never duplicates its rows.
- **Policy and architecture** → `iverilog_ieee1800_uvm_manifesto.md`.
- **Per-checkpoint history** → `session_logs/`. Everything this file used
  to carry inline (2026-07-14 .. 2026-07-21, ~110 KB) is archived verbatim
  in `session_logs/2026-07-14_to_2026-07-21_current_work_archive.md`.

**Rule:** when a campaign closes, its narrative goes to a dated
`session_logs/` entry and this file keeps only the resume state below.

---

## Resume state — 2026-07-25 (Campaign 1: M6/M7 scheduler and UVM)

**Branch:** `claude/ieee1800-closure-campaign-lqalye`.

**Closed in this campaign so far:**

- **Issue #98** — the UVM phase-hopper objection reaching `uvm_root`. The
  language-level defect behind it was fixed by the #103 work (a nested
  detached fork's implicit `this` resolving to null); this campaign
  supplied the missing half of the acceptance boundary:
  `m7_post_run_phases_test` proves extract/check/report/final all execute,
  in order, after a run_phase held open by two-level concurrent objection
  traffic, with the run still ending at t=80.
- **R2 / M6B-4** — assertion ACTION blocks now run in the **Reactive**
  region (4.4.2.5), one region after the Observed evaluation. The earlier
  attempt at this was reverted for dropping end-of-simulation verdicts;
  both causes were runtime defects and are fixed: `%wait/reactive` runs
  inline wherever no Reactive region is reachable (final blocks,
  Postponed, post-simulation), and a thread resumed by a region deferral
  is exempt from the `of_VPI_CALL` freeze that `$finish` otherwise applies
  mid-body.
- **M6B-2** — `cbNBASynch` (reason code 30) defined, registered and backed
  by a real `SEQ_NBASYNC` queue drained after NBA and before Observed.
- **M6B-3** — time-consuming DPI imports pinned as schedulable processes
  (`join_any` returns while one is parked; `disable fork` abandons it for
  good).

**Preempted into (rule gate 1 — silent wrong results jump the queue):**

- **M3B-8** inherited constraints were solved class by class, so a
  base-only re-solve overwrote the full solution and silently violated a
  derived hard constraint. Now one solve over the complete set.
- **M3B-9** soft-constraint priority (18.5.14.1) was settled by weight
  sum rather than declaration order. Each `soft` is now its own
  lexicographic objective, and the compiler emits inherited constraint
  lists in ascending declaration order so list position is priority.
- **M4B-11** `'{default: value}` was rejected everywhere (parsed as a
  one-element positional pattern) and the `'{N{...}}` replication count
  was dropped by every elaboration path — silently wrong on a packed
  target.

**Campaign 1 is closed.** M6B is COMPLETE (all four items), M7 is
verified at 224/0/0 with an empty known-fail list, and the region
pipeline self-test drains Preponed → Active → NBA → NBASync → Observed →
Reactive → Re-NBA → RWSync → ROSync in order under reverse insertion.

**M1C-1 is fixed.** The ICE — `foreach` over a runtime-sized array inside
a `$unit`-scope class constructor — was a named block scope being
elaborated twice: `PBlock::elaborate_scope` built a second `NetScope` for
the same name under the same parent, orphaning the one the signature pass
had declared the loop variable into. A same-named child of the same
parent is now reused. Pinned by `sv_foreach_in_class_constructor`;
`repros/foreach_in_unit_class_constructor_ice.sv` keeps the minimization
trail.

**M1C-3 is fixed** — the largest thing this campaign has turned up. An
element of a container held in a CLASS PROPERTY was being addressed with
the property-SLOT index, and the slot holds the container, not the
element. Three silent defects fell out of that one shape: null guards
read non-null for null elements (so lazy allocation silently skipped),
member writes through an element hit the container (abort for index ≥ 1),
and whole-element stores of an unpacked struct aliased the source so
every element ended up holding the last value. Pinned by
`sv_class_property_container_element`.

**M1C-4 is fixed.** An unpacked-array member of an interface reached
through a VIRTUAL interface read `x` and dropped writes, silently: the
slot resolver skipped anything that was not a signal / real / string /
base variable, and an unpacked array's VPI handle is a `__vpiArray`, so
the member got no slot at all. An array slot kind now resolves and the
element index selects the word; reals and strings were fixed with it
(their accessors discarded the index outright). Pinned by
`sv_vif_array_member`, which was run against a build with the fix
reverted: reads returned 0 and the first write aborted the runtime.

**M5-6 landed while probing the same family.** `virtual bus_if.drv vif;`
— a modport-qualified virtual interface, IEEE 1800-2017 25.9 and the
standard UVM agent idiom — was a hard syntax error in every declaration
context. It now parses everywhere the unqualified form does, at zero
grammar-conflict cost. The modport view IS enforced through the new
form -- writing an `input` member is rejected and an unlisted member is
inaccessible -- which corrected this row's first, wrong claim that it was
not.

**No silent defect is known to be outstanding in the M1C access family.**
Every cell of the two Cartesian probes and the ~110-cell adversarial
matrix now passes, and the remaining gaps in that family are LOUD: a
struct-typed array member through a virtual-interface handle (nested
member path sorry) and `foreach` over an interface-instance array member
(unresolved-target error). The open architecture item is M1C-2, the
canonical access representation itself.

---

## Resume state — 2026-07-26 (Campaign 3: M3B randomization, then M9 clause 16)

**Campaign 3 is closed for the `randomize()` call-semantics family.**
Four IEEE clauses answer one question — which variables does this call
solve for? — and all four were wrong in the same direction, silently:

- **M3B-11** a property that is not `rand` is a STATE variable (18.3);
  every constraint item that mentioned one was dropped, so
  `constraint c { a == b; }` with a non-rand `b` was no constraint at
  all and `randomize()` returned 1 with it violated.
- **M3B-12** `rand_mode(0)` skipped the pre-fill but the solver still
  solved the variable and wrote it back, so a frozen field moved
  anyway; and `rand_mode()` as a function was a constant 0, which broke
  the save/restore idiom in the disabling direction.
- **M3B-13** the `randomize(a, b)` argument list was discarded —
  `randomize(b)` randomized the whole object and `randomize(null)`
  mutated it instead of only checking satisfiability (18.11).
- **M3B-14** `post_randomize()` ran after a FAILED randomize (18.6.2).

One mechanism carries the first three: every class property reference is
an ordinary solver variable and the SOLVE decides what it is solving
for, pinning everything else to its current value. `%rand/active`
carries the 18.11 set from elaboration; `%rand_mode/get` answers the
query form. Pinned by `sv_randomize_variable_control`, verified against
a build with the fixes reverted.

**M9-12 preempted the rest of Campaign 3** (rule gate 1). The sampled
value functions used PROCEDURALLY — `$past`/`$rose`/`$fell`/`$stable`
outside a concurrent assertion — were compile-progress VPI stubs:
`$past(e)` returned `e`, `$rose` returned 0, `$stable` returned 1, with
no diagnostic. `always @(posedge clk) if ($rose(req))` silently never
fired. They now bind to the enclosing block's clock (16.14.6) through
the same rewrite the assertion engine uses; the tick count, the gating
expression, 1-bit boolean results, 64-bit history and real-typed
history all came with it, and `$changed` exists at all for the first
time. Pinned by `sv_sampled_value_procedural`.

**This corrected a false claim in ROADMAP.md**, which asserted that
every M9 residual was loud and clause 16 had no silent-miscompile gap.

**M3B-15 followed from the same family.** A constraint expression is an
ordinary SV expression, evaluated at the CONTEXT width (11.6.1,
Table 11-21), not the operand width. The solver used the operand
width, so `constraint { a + b == 300; }` with two 8-bit rand variables
wrapped mod 256 and came back UNSAT — `randomize()` returned 0 for a
set with 155 solutions — and `s == a * b` with a 32-bit `s` solved `s`
to the low 8 bits of the product. `inside` and `dist` truncated their
bounds down to the subject's width, rewriting `x inside {[0:300]}` on
an 8-bit `x` into `[0:44]`. Arithmetic is now built at full precision
and truncated at the comparison to the max of the two sides'
self-determined widths — so a wide context does not wrap and a narrow
one still does. Pinned by `sv_constraint_expr_width`.

**The sampler is its own process.** The first cut spliced the capture
and the shift around the reader's block body, which is wrong for a
block that WAITS inside itself: the history then advanced once per
execution instead of once per clock tick, silently. It is now an
`always @(<the same event>)` process shifting under NBA — it ticks with
the clock whatever the reader does, and the NBA update lands after
every Active-region reader, so sharing the edge is race-free. That
construction also gave the `default clocking` binding for free, so all
three clock sources of 16.14.6 are covered.

**Known open, in priority order:** R14 (an explicit clocking-event
argument to a sampled value function does not parse — the lowering
exists, only the grammar rule is missing); M3B-10
(`std::randomize(vars) with {...}` does not reach Z3);
`obj.randomize() with {...}` in STATEMENT position is a syntax error
(only the expression form parses); M1C-2 (canonical access
representation); M9-7 multiclock residuals.

**Where to look first when resuming:** the `Current focus` list at the
bottom of `ROADMAP.md`. It is re-derived from the priority rule, not
hand-picked.
