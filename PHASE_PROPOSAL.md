# IEEE 1800 + UVM Coverage — Phased Proposal

**Status:** draft for approval
**Scope:** functional correctness only (no perf work)
**Out of scope:** event-loop parallelism, JIT, OT smoke completion (separate)

## Triage of current gaps

Concrete evidence (audited 2026-05-02 on `development`):
- 36 `sorry:` stubs in elab_expr.cc, 24 in elaborate.cc, 3 in elab_sig.cc → ~64 explicit-unimplemented sites
- ~30 `compile-progress` silent fallbacks in elab files
- 28 null fallbacks in tgt-vvp/eval_object.c
- 9 visible UVM-compile warnings on a simple test (rgtry.initialize, uvm_pair.copy, compare(), Cast-to-queue, $ivl_queue_method$sort, etc.)
- 4 skipped canonical tests (2 modport-port, 1 string-ternary, 1 plusarg harness gap)

These cluster into 5 themes. The phases below address them in dependency order — each builds on what came before.

---

## Phase A — Compile-time blockers (P0)

These cause CURRENT testbenches to either fail-to-compile or silently produce wrong results. Fix first.

| # | Item | Symptom | Effort |
|---|---|---|---|
| A1 | Modport-typed module ports (`module m(if.modport p)`) | `tests/vif_smoke.sv` syntax error at line 7 | medium |
| A2 | String ternary with mixed string/concat operands | `bit ? "literal" : {"prefix_", str}` collapses to empty (`tests/string_ternary_test.sv` FAIL) | small |
| A3 | LHS streaming `{<<{x}} = src` | Currently parses (per C5) but lvalue not elaborated; UVM `uvm_packer` uses this | medium |
| A4 | `Cast to queue` correct semantics (not bits-reinterpret) | UVM `uvm_reg_map.svh:2160/2169` warns and silently mis-casts | small |
| A5 | UVM `__tmp_int_t__` internal typedef resolution (uvm_agent.svh:127) | `Can not find the scope type definition` warning; field-macro state may be wrong | medium |

**Acceptance:** the 4 SKIP tests pass (or 2 of them — the modport ones share a fix); UVM compile produces zero `compile-progress` warnings against the listed lines.

---

## Phase B — Silent-degradation kills (P1)

These compile cleanly but produce wrong runtime behavior. Each is a "you ran your test, got a green tick, and the test was a lie" situation.

| # | Item | Symptom | Effort |
|---|---|---|---|
| B1 | Queue `find()` / `find_index()` / `find_first` | `sorry: 'find()' ...` → returns null/empty silently | medium |
| B2 | `compare()` method on classes | `compile-progress: object has no method "compare(...)"` → returns 0 | small |
| B3 | uvm_pair `.copy()` | `Enable of unknown task` → no-op | small |
| B4 | `rgtry.initialize` (factory typedef registry) | task-enable ignored → factory may register late | small |
| B5 | `$ivl_queue_method$sort` on non-signal queue | `requires a signal ... skipping` → queue not sorted | medium |
| B6 | `function copy-out argument for value` | aggregate function returns drop on the floor | medium |
| B7 | I6 tagged-union tag/pattern enforcement | tagged unions parse but tag-discriminated access doesn't enforce → reads wrong union member | medium |
| B8 | C6 `std::randomize(x) with{...}` clause enforcement | with-clause silently dropped → randomize ignores user constraints | medium |
| B9 | Detached fork autotask context retention (FALLBACKS.md frontier) | `vthread_get_rd_context_item_scoped could not find a live automatic context` after parent task returns | large |

**Acceptance:** compile-progress count for these specific patterns drops to 0; targeted regression tests for each.

---

## Phase C — UVM real-testbench coverage (P2)

These are needed for OT-class testbenches end-to-end. Some require Phase B prerequisites (notably B5/B6/B9).

| # | Item | Notes | Effort |
|---|---|---|---|
| C1 | uvm_reg full backdoor (`hdl_path_concat`, `peek/poke`) | Currently partial; affects RAL flows | large |
| C2 | uvm_objection deep-flow correctness | Already partially works; verify under nested raise/drop | medium |
| C3 | uvm_sequence_library with random selection modes | Stubs exist; verify selection_mode behavior | medium |
| C4 | uvm_phase_timeout watchdog actually fires | OT smoke documents `+test_timeout_ns` is silently ignored | medium |
| C5 | uvm_callback chain on derived parameterized types | I5 fixed the base case; verify with real OT callbacks | medium |
| C6 | DPI plusarg via uvm_cmdline_processor in test harness | C4 verified manually via `vvp -d uvm_dpi.so`; need .github/uvm_test.sh hook | small |

**Acceptance:** OT UART DV smoke compiles and runs without `compile-progress` warnings on the UVM stdlib path; one of {csr_rw, csr_aliasing} csr-style tests reaches "Finished test sequence".

---

## Phase D — Coverage and cross (P3)

| # | Item | Notes | Effort |
|---|---|---|---|
| D1 | Cross-body explicit bin specs (`binsof(...) intersect`, `binsof(...) && binsof(...)`) | Parser captures, no semantics | medium |
| D2 | Coverage `@(posedge ...)` sample triggers | Currently sample is explicit; auto-trigger missing | medium |
| D3 | `option.weight`, `option.at_least`, `option.cross_auto_bin_max` | option.field accepted but ignored | small |
| D4 | `transition_seq_list` bins (`bins b = (a => b => c)`) | Parser captures, no semantics | medium |

**Acceptance:** A coverage test exercising all 4 features passes.

---

## Phase E — Hardening / cleanup (P4)

| # | Item | Notes | Effort |
|---|---|---|---|
| E1 | Convert remaining "silent fallback" sites to explicit warnings | 28 in tgt-vvp/eval_object.c, 63 in elab_expr.cc | small per site |
| E2 | Audit pass: re-count `sorry:` and `compile-progress` markers; document remaining as "P5+ not on roadmap" | mechanical | small |
| E3 | IEEE 1800 conformance subset test list | Pull a public conformance test set (or write one) and run it; document pass rate | medium |
| E4 | Re-skip-list the canonical UVM regression — items that should now pass | mechanical | small |

**Acceptance:** A documented "what does iverilog support / what doesn't" matrix.

---

## Sequencing recommendation

```
A1, A2, A4 (small) → A3, A5 → B2, B3, B4 (small batch) → B1, B5, B7, B8 → B6, B9 → C4 → C5, C6 → C1 → C2, C3 → D series → E series
```

A small items (A1, A2, A4) and B small items (B2, B3, B4) can be batched as 2 days of fixes each.

Larger items (A3 LHS streaming, B1 find/find_index, B9 detached-fork context, C1 uvm_reg backdoor) are 1–3 days each.

C-phase work depends on B-phase prerequisites (B5 sort, B6 copy-out, B9 context retention).

Estimated total: ~3 weeks for A+B, ~2 weeks for C, ~1 week for D, ~1 week for E. Total ~7 weeks for "iverilog supports IEEE 1800 + UVM at the level needed for typical commercial UVM testbenches to compile cleanly and run correctly (perf aside)."

---

## What this DOES NOT cover

- Performance (event-loop parallelism, JIT, scheduler rewrite) — tabled per perf-mt branch investigation
- OT UART smoke completion in reasonable wallclock — bound by perf, not features
- IEEE 1800 features rare in real testbenches (rare DPI corners, system tasks like $sformat to bit-vector, some clocking-block edge cases) — left as P5+

## Open questions for approval

1. **Order**: do you want A→B→C→D→E (proposed) or interleave (e.g., A+B per area before moving to next)?
2. **Tests**: each item gets one regression test in `tests/`. OK to commit them per-item, or batch?
3. **Phase 62 numbering**: continue (`Phase 62o, 62p...`) or start a new banner (`Phase 63a, 63b...`)?
4. **Branch strategy**: all on `development` (current), or feature branches per phase?
