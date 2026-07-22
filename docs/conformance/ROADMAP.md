# IEEE 1800 / UVM Conformance Roadmap — canonical execution tracker

This is the **single source of truth for what is left and in what order.**
It is deliberately built to *not drift*.

- **Detail & history** live in `iverilog_ieee1800_uvm_manifesto.md` (per-milestone
  truth status) and `matrices/ieee1800_2017_clause_matrix.md` (clause dispositions).
- **This file** holds the stable work-breakdown, the fixed ordering rule, and the
  one derived "current focus" pointer. Nothing else.

**Supersedes as a *tracking* device:** `frontier_roadmap_2026-07-17.md` and every
`session_logs/*` "Tier 1/2/3" list. Those are dated snapshots. There is exactly one
living tracker: this file. Do not introduce new Tier/Phase schemes.

---

## Why this does not churn (the anti-drift contract)

1. **The spine is the milestone set M0–M15**, taken verbatim from the manifesto.
   Milestones never renumber. Work-item IDs (below) never change.
2. **Priority is not stored — it is computed** by the fixed rule below over each
   item's *nature* + *dependencies* + *status*. There is no hand-maintained
   priority list to re-shuffle, so there is nothing to churn.
3. **Only two things ever change** in normal operation: an item's **Status**, and
   the single **Current focus** pointer at the bottom (mechanically re-derived from
   the rule, not hand-picked).
4. New discoveries **append** an item to the owning milestone; they never
   reorganize the structure.

## The fixed priority rule (do not edit)

Apply top-down; the first gate that matches wins. This restates manifesto
principle 2 + the Execution Order note, made mechanical:

1. **CORRECTNESS** — a *silent* wrong result. Always first, jumps the queue.
2. **ROBUSTNESS** — a crash / ICE (loud but ungraceful).
3. **FEATURE** — a missing but self-contained construct real testbenches hit.
4. **AUDIT** — a probe that may surface hidden silent bugs (high ROI; interleave).
5. **ARCHITECTURE** — a rearchitecture that unblocks a cluster (staged behind a flag).
6. **CAMPAIGN** — exhaustive subclause sweep / 2023 delta. Last.

**Dependency override:** an item whose `Blocked-by` names an ARCHITECTURE item
cannot start until that item lands, regardless of nature.

Every work item carries exactly one **Nature** from that list. Nature is intrinsic
to the item and does not change; Status does.

**Definition of Done:** an item is `DONE` only when it meets all 18 criteria in the
manifesto "Definition of done" section (clause identified → syntax → diagnostics →
types → elaboration → runtime → scheduling/VPI/DPI where applicable → positive +
negative + interaction tests → UVM green → baseline-clean → docs updated → committed).
The per-item "Done when" column names the *specific* acceptance beyond that baseline.

Status values: `DONE` · `PARTIAL` · `OPEN`.

---

## The spine: milestone execution order

This is the manifesto's Execution Order. It is the stable backbone; the work
breakdown that follows is grouped under it.

| # | Milestone | Area | Status |
|---|-----------|------|--------|
| — | M0 | Reproducible baseline | DONE |
| — | M1A | Typed receiver / chained dispatch | DONE |
| — | M2 | UVM factory/config/callbacks/fields | DONE (scope) |
| — | M3A | Common class constraint solving | DONE (common) |
| — | M4A | Core container runtime | DONE (core) |
| — | M6A | Core scheduler/runtime repairs | DONE (subset) |
| — | M7 | Accellera UVM qualification | DONE (harness 209/0/0) |
| — | M8 | Clocking blocks & program sched | PROVISIONAL |
| — | M9A | Core SVA token pipeline | DONE |
| — | M10A | Core DPI imports & packed vectors | DONE (subset) |
| — | M11A | Class functional-coverage core | DONE |
| — | M12A | Core SV VPI object model | SUBSTANTIAL |
| — | M13A | Long-tail core | DONE (subset) |
| — | M14A | Clause matrix (top-level) | DONE |
| 4 | **M1B** | Specialization/aggregate typing fidelity | PARTIAL |
| 5 | **M5** | Interfaces & modports | PARTIAL |
| 6 | **M6B** | Scheduler conformance | PARTIAL |
| 6 | **M8** | Clocking reprobes | PROVISIONAL |
| 3 | **M3B** | Full clause-18 randomization | PARTIAL |
| 3 | **M4B** | Aggregate/container completion | PARTIAL |
| 7 | **M9B/C/D** | SVA sequence/temporal/automaton | AUTOMATON LANDED; M9-9 checker + M9-7 residuals OPEN |
| 8 | **M10B/C** | DPI completion | PARTIAL |
| 9 | **M11B** | Coverage declaration/sampling surface | PARTIAL |
| 10 | **M12B/C** | VPI completion | PARTIAL |
| 11 | **M13B** | Long-tail tails | PARTIAL |
| 12 | **M14B** | Exhaustive subclause campaign | OPEN |
| 13 | **M15** | IEEE 1800-2023 delta | OPEN |
| — | **M1C** | Canonical semantic-IR migration | OPEN (architecture) |

---

## Work breakdown (open items only)

IDs are stable. `Nature`: C=correctness, R=robustness, F=feature, A=audit,
X=architecture, K=campaign.

### M1B — specialization & aggregate typing fidelity  (clause 6/7/8)

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M1B-1 | Member access on element of static/dynamic unpacked-struct array | C | **DONE** (#106/#107) | — | static+dyn+queue member r/w + `%p`; lazy element ctor |
| M1B-2 | Struct value-copy on assignment (was reference-alias) | C | **DONE** (#108) | — | scalar/array/darray/queue `=` copy; class handle still aliases |
| M1B-3 | Remove compile-progress fallbacks caused by lost specialization | C | OPEN | — | each silent type-recovery fallback → tracked diagnostic or fix |
| M1B-4 | Adversarial parameterized-UVM specialization regressions | A | OPEN | — | generated multi-specialization suite, all correct |

### M4B — aggregate/container completion  (clause 7/21)

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M4B-1 | Struct value-copy through method args / return / `push_back(var)` | C | OPEN | — | by-value struct arg & return copy independently |
| M4B-2 | Nested unpacked-struct **deep** copy (current copy is shallow) | C | OPEN | — | nested struct member copied by value, not shared |
| M4B-3 | Adversarial nested-container testing | A | OPEN | — | generated nested array/queue/assoc/struct suite clean |
| M4B-4 | `%p` on packed struct → `'{member:val}` (prints one decimal) | F | OPEN (deferred, cosmetic) | — | packed struct prints member pattern |
| M4B-5 | `%p` nested unpacked dims print nested not flat | F | OPEN (deferred, cosmetic) | — | multi-dim prints `'{'{..},..}` |

### M5 — interfaces & modports  (clause 25)

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M5-1 | Modport member visibility (read + write) | C | **DONE** | — | listed-only access; CE tests |
| M5-2 | Interface-member change-sensitivity (all r-value forms) | C | **DONE** | — | bare/indexed/operator/multi/mixed, both edges |
| M5-3 | Runtime-index vif-array binding `vp[i]=pins[i]` in a loop | F | OPEN | — | needs runtime instance-dispatch table |
| M5-4 | Bare `$unit`-scope `virtual iface v;` (parse error today) | F | OPEN | — | parses & binds at $unit scope |
| M5-5 | Generic `interface` ports | F | OPEN | — | generic port binds to any matching iface |

### M3B — full clause-18 randomization  (clause 18)

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M3B-1 | `randcase` / `std::randomize(var)` / `unique {}` | F | **DONE** | — | tests landed |
| M3B-2 | `randsequence` | F | OPEN | — | production grammar → weighted lowering |
| M3B-3 | `disable soft` | F | OPEN | — | soft-constraint removal honored |
| M3B-4 | Reaudit `rand_mode` / `constraint_mode` combinations | A | OPEN | — | all combos correct incl. per-field |
| M3B-5 | Seed-stability + failed-randomization state tests | A | OPEN | — | deterministic seed + fail-state coverage |

### M6B — scheduler conformance  (clause 4)

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M6B-1 | Per-instance class events; process suspend/resume/status | F | **DONE** | — | tests landed |
| M6B-2 | Post-NBA VPI callback region (cbNBASynch) | F | OPEN | M6-CALLF | post-NBA callbacks fire in region |
| M6B-3 | Scheduling for time-consuming DPI imports | F | OPEN | M6-CALLF | DPI task may consume time |
| M6B-4 | Assertion attempt-lifecycle scheduling | F | OPEN | ARCH M9-NFA | per-attempt start/step/end regions |

### M8 — clocking blocks (PROVISIONAL — audit owed)  (clause 14)

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M8-1 | Reprobe edge-qualified skew forms | A | OPEN | — | each skew form verified vs spec |
| M8-2 | Reprobe real/string/aggregate clockvars | A | OPEN | — | non-integral clockvars correct |
| M8-3 | Parameterized vif clocking stress | A | OPEN | — | per-specialization clocking correct |
| M8-4 | Clocking + program + assertion + VPI ordering stress | A | OPEN | — | region ordering litmus green |
| M8-5 | Every clause-14 subfeature has a disposition | K | OPEN | — | subclause matrix rows + tests |

### M9 — SVA  (clause 16/17)

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M9-1 | Bounded liveness/safety `nexttime[n]`,`eventually[m:n]`,`always[m:n]` | F | **DONE** (PR #109) | — | windowed lowering + tests |
| M9-2 | Abort operators `accept_on`/`reject_on`/`sync_*` | F | **DONE** (PR #109) | — | boolean-operand sampled gating + tests |
| M9-3 | Property combinators `implies`/`iff`/`if-else`/`case` property | F | **DONE** (PR #109) | — | boolean-combinator lowerings + tests |
| M9-4 | Goto / nonconsecutive repetition `b[->n]` `b[=n]` | F | **DONE** (NFA C.1) | — | plain-seq + `##N` + `\|=>` consequent; `##0`-fused `\|->` consequent is a loud sorry corner |
| M9-5 | Local sequence variables `(a, v=e) ##1 (b && f(v))` | F | **DONE** (NFA LV-1/LV-2) | — | fixed + variable-delay per-slot storage |
| M9-6 | `.matched` / complete `.triggered` / strong-weak sequences | F | **DONE** (NFA C.2/C.3) | — | endpoint methods + strong/weak obligation |
| M9-7 | Multiclock sequences | F | **PARTIAL** (NFA D.1) | — | `\|=>` CDC handshake done; mid-seq clock flow / cross-clock `\|->` / multi-cycle CDC operands are loud errors |
| M9-8 | Variable-length `intersect` / `within` | F | **DONE** (NFA B.2/B.4) | — | non-fixed operands over the automaton |
| M9-9 | `checker`/`endchecker` (clause 17; today a loud sorry) | F | **OPEN** | — | real checker instantiation |
| M9-10 | Procedural concurrent assertion forms | F | **MOSTLY DONE** | — | clocked `assert property` in a proc block elaborates; needs the always-block edge as implicit clock + audit |
| M9-11 | `expect` statement | F | OPEN | **M6-CALLF** | process blocks on a property |

**M9 status note (corrected 2026-07-22).** The **M9-NFA per-attempt
automaton engine is LANDED and is the default SVA engine** — stages
A/B/C/D.1 all shipped in prior sessions (design doc
`m9_nfa_design_2026-07-19.md`), verified by `tests/sva_nfa/run.sh`
(dual-run 33/33: automaton vs legacy verdict-parity, plus nfa-only golds).
M9-4/5/6/8 are therefore DONE via the automaton; M9-7 is PARTIAL (the
`|=>` CDC handshake works, harder multiclock forms are loud errors). The
boolean-collapse operators M9-1/2/3 (PR #109) fill in the pieces the
automaton doesn't need. **Every M9 residual is a LOUD rejection — there is
no silent-miscompile gap anywhere in clause 16.** The genuine remaining
frontier is **M9-9 (checker/endchecker, clause 17)** — the largest
unimplemented SVA feature — plus the M9-7 multiclock residuals, the
`##0`-fused goto-consequent corner, and eventual legacy-engine retirement.

### M10B/C — DPI completion  (clause 35)

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M10-1 | Multidimensional open arrays (`svGetArrElemPtr2/3`) | F | OPEN | — | 2-D/3-D open-array access |
| M10-2 | DPI export (C→SV) | F | OPEN | **M6-CALLF** | C calls an SV export via shim |
| M10-3 | Real context semantics / `chandle` ABI verification | A | OPEN | — | context + chandle round-trip tests |
| M10-4 | Time-consuming imported tasks | F | OPEN | **M6-CALLF** | import task consumes time |
| M10-5 | C→SV→C reentrancy + cross-platform DPI regressions | A | OPEN | M10-2 | Linux/macOS/Windows green |

### M11B — coverage surface  (clause 19)

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M11-1 | Package-scope covergroups | F | OPEN | — | package cg samples |
| M11-2 | Module/interface-scope covergroups | F | OPEN | — | non-class cg samples |
| M11-3 | Complete sampling-event forms | F | OPEN | — | all `@(...)` sample forms |
| M11-4 | `with function sample` formal semantics | F | OPEN | — | sampled formals correct |
| M11-5 | Coverpoint-expression + option/type_option audit | A | OPEN | — | arbitrary exprs + all options |
| M11-6 | Coverage serialization/interchange + adversarial cross/transition | A | OPEN | — | durable format + generated tests |

### M12B/C — VPI completion  (clause 36/38/40)

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M12-1 | Assertion start/step/disable lifecycle callbacks | F | OPEN | ARCH M9-NFA | cbAssertion* fire |
| M12-2 | Populate `s_vpi_attempt_info` | F | OPEN | ARCH M9-NFA | real attempt detail |
| M12-3 | Bit-select force/release + cbForce/cbRelease | F | OPEN | — | force/release on bit-selects |
| M12-4 | Associative-array element writes via VPI | F | OPEN | — | assoc element put_value |
| M12-5 | Nested class-member traversal | F | OPEN | — | multi-level member descent |
| M12-6 | Modport direction/access metadata | F | OPEN | — | modport dirs exposed |
| M12-7 | Covergroup drill-down handles | F | OPEN | — | bin-level handles |
| M12-8 | VPI object lifetime/free behavior | A | OPEN | — | defined free semantics + tests |

### M13B — long-tail tails  (clause 23/28/31)

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M13-1 | Bind to specific instance path | F | OPEN | — | instance-path bind |
| M13-2 | Bind target-instance lists | F | OPEN | — | list-target bind |
| M13-3 | `config` semantics + library mapping | F | OPEN | — | real config resolution |
| M13-4 | `trireg` charge semantics | F | OPEN | — | charge decay model |
| M13-5 | `$nochange` / `$timeskew` / `$fullskew` | F | OPEN | — | remaining timing checks |
| M13-6 | Timing-check edge-descriptor lists + timestamp/timecheck conds | F | OPEN | — | edge lists + conds |
| M13-7 | `pulsestyle` / `showcancelled` | F | OPEN | — | pulse controls honored |

### M14B — exhaustive subclause campaign  (all clauses)

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M14B-1 | Correct stale FULL labels; re-evaluate FULL rows with corners | K | OPEN | — | matrix labels match reality |
| M14B-2 | Downgrade clauses 19/31/35/36 to reflect gaps | K | OPEN | — | honest dispositions |
| M14B-3 | Subclause-level evidence + link rows to permanent tests | K | OPEN | — | every row has a test link |
| M14B-4 | Adversarial/generated silent-miscompile hunt; zero-silent-gap policy | K | OPEN | — | generated sweep clean |

### M15 — IEEE 1800-2023 delta  (2023 spec)

| ID | Item | Nat | Status | Blocked-by | Done when |
|----|------|-----|--------|-----------|-----------|
| M15-1 | 2023 delta scoping + clause matrix | K | OPEN | M14B, all P0/P1 | delta enumerated |

---

## Architecture big rocks (unblock clusters; staged behind flags)

These are the only items that gate large downstream clusters. Land them in order;
each behind its existing feature flag with the named litmus suite as the gate.

- **ARCH-1 · M9-NFA** — NFA-based sequence matcher replacing the flat linear token
  chain. **Unblocks:** M9-4…M9-10, M6B-4, M12-1, M12-2. *Recommended first big rock*
  (lower risk than the scheduler; unblocks the most distinct features). Stage:
  thread model → local vars → repetition → strong/weak → multiclock, behind the
  existing linear path so nothing regresses. Gate: full SVA suite + negative SVA.
- **ARCH-2 · M6-CALLF** — scheduled-call / function-atomicity protocol
  (`IVL_SCHED_CALLF`, currently flagged off). **Unblocks:** M10-2 (DPI export),
  M9-11 (`expect`), M10-4 (time-consuming DPI), M6B-2/M6B-3 (post-NBA VPI).
  Higher risk; sequence *after* ARCH-1. Gate: the race/region litmus suite.
- **ARCH-3 · M1C** — canonical semantic-IR migration (type descriptor, typed lvalue
  + aggregate-layout interfaces, bypass-path inventory). Foundational and
  cross-cutting; do as narrow, test-guarded conversions **interleaved** whenever a
  nearby silent type-recovery fallback (M1B-3) is touched — never as a big-bang.

Dependency graph (arrows = "unblocks"):

```
ARCH-1 M9-NFA ──▶ M9-4,5,6,7,8,9,10 · M6B-4 · M12-1,2
ARCH-2 M6-CALLF ─▶ M10-2 (DPI export) · M9-11 (expect) · M10-4 · M6B-2,3
ARCH-3 M1C ──────▶ (reduces M1B-3 silent-fallback risk; interleaved)
```

---

## Compliance scorecard (measurable, clause-level)

From `matrices/ieee1800_2017_clause_matrix.md` (M14A, top-level of 36 clauses).
Several PARTIAL rows are now *stale-conservative* (fixed after the matrix was
written); M14B-1 will reconcile them.

| Disposition | Count | Meaning |
|-------------|-------|---------|
| FULL | 21 | core + probed subfeatures correct |
| PARTIAL | 15 | core correct, specific corners recorded |
| DIAGNOSED | 3 | loud, not implemented (e.g. checkers) |
| N/A | 4 | informative/organizational |

**Honest headline:** ~90% of the common / UVM-relevant IEEE 1800-**2017** surface
works correctly (UVM 209/0/0, no known silent miscompiles). The residual is
*concentrated* in three places — advanced SVA (M9-4…M9-10, needs ARCH-1),
DPI export + multidim open arrays (M10-1,2, export needs ARCH-2), and checkers
(M9-9). Full standards-complete compliance is **not** claimed and cannot be
certified until **M14B** (subclause audit) closes. IEEE 1800-**2023** (M15) is ~0%,
deliberately gated.

---

## Current focus (the only mutable ordered list — derived from the rule)

Re-derive this by applying the priority rule to the OPEN items above; do not hand-edit
the structure. As of this writing (no known silent miscompiles outstanding, robustness
clear), the frontier is bounded FEATURE + AUDIT work, then the first big rock:

1. **M4B-1 / M4B-2** — struct value-copy through args/returns + nested deep copy
   (CORRECTNESS residual from the assignment work; highest nature).
2. **M1B-3** — convert lost-specialization compile-progress fallbacks to diagnostics
   (CORRECTNESS; interleave ARCH-3/M1C conversions here).
3. **M8-1…M8-4** — clocking reprobes (AUDIT; PROVISIONAL status owes this; high ROI —
   this is the audit class that surfaced the M5 "dispatch-through-element-0" bug).
4. **M5-3 / M5-4 / M5-5** — vif runtime-index binding, `$unit` vif decl, generic ports (FEATURE).
5. **M3B-2 / M3B-3**, **M9-1 / M9-2 / M9-3** — bounded randomization + bounded SVA
   operators (FEATURE; no architecture dependency).
6. **ARCH-1 · M9-NFA** — first big rock; retires M9-4…M9-10 + M12-1,2 + M6B-4.
7. **ARCH-2 · M6-CALLF** — second big rock; unblocks DPI export + `expect` + time-consuming DPI.
8. **M14B** subclause campaign → **M15** 2023 delta.

**Standing override:** any newly discovered silent miscompile or crash preempts this
list (rule gates 1–2).
