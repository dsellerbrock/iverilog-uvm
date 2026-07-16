# Milestone Truth Audit — 2026-07-16

Purpose: a constructively adversarial re-classification of milestones
M1–M14 against their **manifesto-defined scope**, correcting
"CLOSED" labels that were justified only by a recorded-corners ledger.

**Rule applied:** a milestone is COMPLETE only if its defined scope is
actually satisfied. A recorded unsupported corner does **not** count as
complete when that corner was part of the original milestone scope.
Historical session logs are preserved unchanged; this document is the
dated correction layer.

## Classification key

- **COMPLETE** — defined scope satisfied; remaining omissions are
  genuinely outside scope.
- **SUBSET COMPLETE** — a well-defined, coherent subset is done and
  correct; named sub-features in scope remain, tracked as explicit
  successor milestones.
- **PARTIAL** — core works but material in-scope functionality is
  missing or only diagnosed.
- **DEFERRED** — scope explicitly moved to a named successor milestone.
- **NOT IMPLEMENTED**.

## Corrected status table

| Milestone | Prior label | **Corrected** | Basis |
|-----------|-------------|---------------|-------|
| M0 Baseline | CLOSED | **COMPLETE** | Probes imported, commands documented, baselines recorded. |
| M1 Semantic IR foundation | CLOSED | **SUBSET COMPLETE (M1A)** | Typed receiver/method dispatch, return-type preservation, method/property lookup on expressions, enum/param identity, virtual dispatch metadata are done. The manifesto ALSO defines a canonical semantic type descriptor, typed lvalue + aggregate-layout interfaces, converting silent type-recovery fallbacks into tracked diagnostics, and documenting bypass paths — that broader migration is **not** done. Split: **M1A COMPLETE** (dispatch/type-preservation), **M1B NOT STARTED** (semantic-IR remediation: typed lvalue/aggregate interfaces, fallback-to-diagnostic conversion, bypass inventory). |
| M2 Factory/config/callbacks/fields | CLOSED | **COMPLETE (application-scoped)** | Defined by concrete UVM fixes, all satisfied and evidenced by the UVM suite. |
| M3 Constraint solver | CLOSED | **PARTIAL** | Broad constraint semantics work, but `rand_mode(0)` on a **specific field** (`obj.field.rand_mode(0)`) is a **silent no-op** (elaborate.cc:5680) — a frozen field is still randomized. That is in-scope randomization behaviour and silently wrong. **Reopened as M3-rm.** |
| M4 Container runtime | CLOSED | **SUBSET COMPLETE** | Arrays/queues/assoc/string unified and broadly correct, BUT string/real-**valued** integer-keyed associative reads (`string s[int]`) are still wrong (only the `obj`-key runtime load opcode exists). The vec4-valued integer-key read was fixed in M14. **Corner in scope → M4-av.** |
| M5 Interfaces and modports | CLOSED | **SUBSET COMPLETE** | Connection/array/modport/vif behaviour works (UVM vif pattern passes). Bare module-scope `virtual <iface> v;`, generic `interface` ports, and continuous-assign through a modport (ICE) remain. **M5-if.** |
| M6 Scheduler architecture | CLOSED | **PARTIAL** | Significant call-execution/scheduler work landed (m6 logs), but the manifesto requires a scheduling-queue inventory, IEEE event-region mapping, scheduler trace + invariant checking, and race litmus tests. The event-region mapping and invariant tooling are **incomplete**. **Reopened as M6B** (scheduler conformance audit + remediation); see the new inventory in `scheduler_conformance_inventory.md` (to author). |
| M7 UVM core qualification | CLOSED | **SUBSET COMPLETE** | The UVM harness (163 tests) exercises factory/config/callbacks/reporting/phasing/sequences/TLM/fields/resource-db. Full register-model and objections stress remain lightly covered. |
| M8 Clocking blocks | CLOSED | **COMPLETE (within stated scope)** | Input skew, output drives, ##N, global clocking, vif clocking all correct; remaining corners are genuinely advanced (recorded). |
| M9 Core SVA engine | CLOSED | **SUBSET COMPLETE** | The manifesto title is "**Core** SVA engine" and the core (implication, ##N/##[m:n]/##[m:$], repetition, not/first_match, sampled functions, named decls, cover) is solid. But major sequence/property operators are unimplemented. Split: **M9A COMPLETE** (core); **M9B PARTIAL** (sequence algebra: `and`/`or` work, `intersect` NOT); **M9C IN PROGRESS** (temporal operators: **`throughout` now implemented** this session; `within`, `until`, `until_with`, `nexttime`, `eventually`, `s_eventually` remain loud sorries); **M9D NOT STARTED** (local sequence vars, parameterized property/sequence bodies, `.matched`, `expect`, strong operators, goto/nonconsecutive repetition). |
| M10 DPI and open arrays | CLOSED | **SUBSET COMPLETE** | libffi marshaling, import task/func, output/inout copy-back, **one-dimensional** open arrays are done. Multi-dimensional open arrays, packed `svLogicVecVal`/`svBitVecVal` vector marshaling, and **exported** tasks/functions (still a sorry) are in scope and unfinished. **M10B.** |
| M11 Functional coverage | CLOSED | **COMPLETE (within stated scope)** | Clause-19 bin semantics, transitions, crosses/binsof/intersect, ignore/illegal/default, iff, options, instance+type coverage, queries, report all work and are tested. Remaining items (VPI drill-down below the covergroup handle) belong to M12/VPI, not M11. |
| M12 VPI SV object model | CLOSED | **SUBSET COMPLETE** | Classes/members/containers/interfaces/modports/packages/covergroup-handles/value-change-callbacks are modeled. **Assertions have NO runtime identities** (`vpi_iterate(vpiAssertion)`→NULL) and force/release on bit-selects + cbForce/cbRelease are unimplemented — all in the clause-36 scope. **M12B** (assertion VPI object model). |
| M13 Bind/let/config/specify/timing | CLOSED | **SUBSET COMPLETE** | bind-by-module/type, let, specify paths, and $setup/$hold/$setuphold/$recovery/$removal/$recrem/$skew/$period/$width are implemented and tested. Explicitly in-scope and NOT done: bind to a specific instance path, bind target instance lists, `$nochange`/`$timeskew`/`$fullskew`, edge-descriptor event lists, timestamp/timecheck conditions, trireg, config (skipped). **M13B.** |
| M14 Clause matrix | CLOSED | **COMPLETE** | Empirical clause matrix delivered; six silent gaps closed. Its own scope (disposition + silent-gap closure) is met — and this audit is the honesty correction M14 implied. |

## False-completion claims found (headline)

1. **M9 "Core SVA engine" CLOSED** while `intersect`/`throughout`/`within`/`until`/`nexttime`/`eventually` were loud sorries. Corrected to SUBSET COMPLETE with the M9A–M9D split; **`throughout` implemented this session** (M9C in progress).
2. **M3 CLOSED** while per-field `rand_mode(0)` silently no-ops (randomizes a frozen field). Reopened M3-rm — this is a **silent wrong-behaviour** gap.
3. **M13 CLOSED** while bind-to-instance, `$nochange`/`$timeskew`/`$fullskew`, and config are unsupported (all loud) — SUBSET COMPLETE.
4. **M10 CLOSED** while multidim open arrays / packed vector marshaling / DPI export are unfinished — SUBSET COMPLETE.
5. **M12 CLOSED** while the assertion VPI object model does not exist — SUBSET COMPLETE.
6. **M1 CLOSED** while the broader semantic-IR migration (typed lvalue/aggregate interfaces, fallback-to-diagnostic conversion) is not started — SUBSET COMPLETE (M1A).

None of the corrected gaps except **M3-rm** and **M4-av** is a *silent* miscompile; the rest are loud diagnostics (honest but incomplete). The two silent ones are the highest-priority reopened technical items.

## This session's technical work (two real implementations)

**M9C `throughout` implemented** (real functionality, not a diagnostic):
`guard throughout seq` lowered to a unit-delay sequence with the guard
AND-ed into every cycle including intermediate ##N wait cycles; exact
for constant delays, loud sorry for variable-window shapes. Adversarial
test verifies a guard-drop at a wait cycle fails.

**M3-rm per-field `rand_mode(0)` implemented** (SILENT wrong-behaviour
fix — the directive's priority #1): `obj.field.rand_mode(0)` now freezes
only that field; it was a silent no-op that still randomized a frozen
field. Intercepted at the top of `elaborate_usr` (before the method
dispatch that dropped it), resolving the field's property index and
emitting the new per-property `%rand_mode/p` opcode. Adversarial test
verifies the frozen field never changes while siblings do, re-enable
restores, and object-level freeze still holds all fields.

Both landed with regression-clean checkpoints; see
`session_logs/2026-07-16_truth_audit_throughout_randmode.md`.

## Reopened work items (priority order; three advanced/closed)

1. ~~**M3-rm** — per-field `rand_mode(0)`~~ **DONE.**
2. **M4-av** — string/real-valued integer-keyed assoc reads (silent). **Highest remaining priority.**
3. **M9C/M9B** — `within`/`until`/`intersect` (loud today; `throughout` done).
4. ~~**M6B** — scheduler conformance inventory~~ **DELIVERED + ADVANCED**: construct-level inventory + `$exit` + **program-completion-ends-simulation (24.7/3.9)** + litmus regressions (`scheduler_conformance_inventory.md`). The two program-control gaps (24.7) are now closed; remaining true M6B gaps (cbNBASynch region, DPI time-consuming tasks, callf scheduled-call protocol) recorded in its ledger.
5. **M10B** — multidim open arrays / packed vector marshaling / export.
6. **M12B** — assertion VPI object model.
7. **M1B** — semantic-IR remediation.

## Next engineering action

Implement **M4-av** (string/real-valued integer-keyed associative-array
reads) — the remaining *silent* wrong-behaviour gap. It needs the
`sig`-form string/vec4-keyed assoc-load opcodes that today exist only
for the `obj`-key case (see M14 matrix, clause 7 corner).
