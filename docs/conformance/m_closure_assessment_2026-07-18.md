# Milestone Closure Assessment — 2026-07-18

Purpose: a hard-nosed answer to three questions after the
automatic-variable-storage refactor (PR #79) and the conformance
campaign (PRs #77/#78/#80) merged: **what is genuinely missing per
milestone, how far in are we, and what is the systematic path to
closure.** Supersedes the status snapshot in
`milestone_truth_audit_2026-07-16.md` (whose corrected labels remain
the baseline) and folds in everything the vendored-suite re-baseline
taught us.

## 1. Verified position (post-merge main)

| Suite | Result | Reference point |
|-------|--------|-----------------|
| vendored ivtest (3101 tests) | **44 fails** (confirmed; 31 pre-existing upstream + 13 documented divergences; the three automatic_events tests moved from Not-Implemented to passing with the refactor) | pristine upstream 13.0: **83 fails** |
| UVM sweep | 187 pass / 0 fail / 1 skip (needs-DPI) | — |
| bundled VPI | 81/81 | — |
| negative suite | 41/41 | — |

The fork now fails **roughly half** as many live-suite tests as the
upstream it forked from, while implementing a large SV/UVM feature
surface upstream lacks (56+ tests upstream fails that the fork passes).
Of the fork's remaining fork-only failures, **every single one is
categorized**: implemented-feature divergences (deferred asserts,
unique-case, digit separators, br1005-family leniencies),
better-diagnostic divergences (struct_invalid_member), and exactly
**two typing-fidelity blockers** (sv_class_new_fail1,
func_empty_arg_fail4). There are **zero unexplained regressions and
zero known silent miscompiles.**

## 2. Milestone-by-milestone: what is actually missing

Statuses below start from the 07-16 truth-audit labels and apply
everything merged since. "≈%" is scope-weighted completion of the
milestone's manifesto-defined scope.

| M# | Status | ≈% | Remaining gap (all loud unless noted) |
|----|--------|----|----------------------------------------|
| M0 baseline | COMPLETE | 100 | — |
| M1 semantic IR | SUBSET (M1A done) | ~55 | **M1B**: canonical type descriptor; typed lvalue/aggregate interfaces; convert the **88 compile-progress fallback sites in 17 files** (elab_expr 34, elaborate 21, elab_lval 8, rest scattered) into tracked diagnostics or real typing; bypass-path inventory. The conformance campaign turned M1B from "diffuse cleanup" into a **measured blocker**: class-typing collapse is the proven root cause of the `uvm_default_*_printer = new()` indistinguishability (sv_class_new_fail1), the registry#(T) virtual-base misresolution (needed the scope-gated virtual-new error), and the unresolved-simple-name policy (func_empty_arg_fail4). |
| M2 factory/config/fields | COMPLETE (app-scoped) | 100 | UVM-suite evidenced. |
| M3 constraints | COMPLETE for audited scope | ~90 | rand_mode fixed; residuals are solver-power corners (constraint shapes "not representable in solver" warn loudly, e.g. uvm_sequence_library's valid_randc_selection). |
| M4 container runtime | SUBSET+ | ~92 | M4-av fixed. This campaign fixed shallow_copy cross-flavor crash + queue warning fidelity. Remaining: container-method long tail behind loud warnings (multi-index array properties fallback in uvm_comparer). |
| M5 interfaces/modports | SUBSET | ~85 | **M5-if**: bare module-scope `virtual iface v;`, generic `interface` ports, continuous-assign through modport (ICE). |
| M6 scheduler | SUBSET+ | ~80 | M6B inventory + $exit + program-completion done; **this campaign** fixed $finish end-of-step semantics (%jmp watchdog overreach) and the refactor (PR #79) landed the single-task-frame model **with detached-fork support upstream doesn't have**. Remaining: **M6-CALLF** scheduled-call/function-atomicity protocol (IVL_SCHED_CALLF, flagged off) — the big rock gating DPI export, `expect`, time-consuming DPI tasks, cbNBASynch region. |
| M7 UVM qualification | SUBSET | ~85 | 187-test harness passes; register-model (beyond reg_basic needs-DPI skip) and objections stress coverage remain thin. |
| M8 clocking | COMPLETE (stated scope) | 100 | advanced corners recorded. |
| M9 SVA | SUBSET (A,B,C,C-live,D-param,E,F?,G?,H? — see note) | ~75 | Core/algebra/temporal/liveness/param/assert-control done per truth audit + frontier items 1–4 if landed. Remaining cluster all sits behind **M9-NFA** (automaton engine): local sequence vars, goto/nonconsec repetition `[->n]`/`[=n]`, `.matched`/strong/weak, multiclock, plus `expect` (also needs M6-CALLF). |
| M10 DPI | SUBSET | ~80 | 1-D open arrays + wide-vector marshaling done. Remaining: **multidim open arrays** (non-contiguous walk) and **DPI export** (blocked on M6-CALLF + C-symbol trampoline). |
| M11 covergroups | COMPLETE (stated scope) | 100 | — |
| M12 VPI | SUBSET+ | ~90 | assertion identity + Success/Failure callbacks done. Remaining: cbAssertionStart/Step/disable + attempt_info.detail; force/release on bit-selects + cbForce/cbRelease. |
| M13 bind/timing | SUBSET | ~80 | bind-to-instance-path, instance lists, $nochange/$timeskew/$fullskew, edge descriptors, config. |
| M14 clause matrix | COMPLETE | 100 | this campaign extends its honesty layer (audit Parts 7–12). |
| **NEW: suite conformance** (this campaign) | NEAR-COMPLETE | ~95 | 66 of 79 fork-only vendored failures fixed; rest documented. Residual: the 2 typing blockers (→M1B) and the policy set (needs only a committed expected-divergence list consumed by the harness, so the gate goes to zero-unexplained). |

**Aggregate: ~85% of manifesto scope implemented and verified.** The
remaining 15% is concentrated, not diffuse: two engine rearchitectures
(M9-NFA, M6-CALLF), one foundational remediation (M1B), and four
bounded feature tails (M5-if, M10B-md, M12B-fr, M13B).

## 3. What the conformance campaign changed in the picture

1. **The gate is now the live upstream suite** (3101 tests, in-tree,
   current golds) with a committed attributed baseline — the strongest
   regression net the project has had. The archived-suite era
   mis-binned 16 "drift" items that were stale golds.
2. **Silent-acceptance debt is paid down measurably**: 25+ CE tests
   that the fork silently accepted now error loudly (darray/queue
   element strictness, enum casts, virtual-new, scoped-binding errors,
   export conflicts, hierarchical-param constants, fatal
   variable-array-word sorries).
3. **M1B got a price tag**: 88 fallback sites / 17 files, and two
   named tests that cannot pass until typing fidelity lands. It is the
   only remaining source of *potential* future silent-acceptance bugs.
4. **The refactor de-risked M6**: automatic storage now matches
   upstream's model (plus detached-fork support), retiring the
   heuristic context-recovery layer — precondition work for M6-CALLF.

## 4. Systematic plan to closure

Ordering principle: finish cheap bounded tails while their context is
fresh → land the two big rocks one at a time behind flags with the
four-gate protocol → drive M1B as the endgame that retires the
compile-progress era. Every phase keeps the standing gate: vendored
ivtest name-diff vs committed baseline, UVM 187/0/1, VPI 81/81,
negative suite, zero-new-fails.

**Phase 0 — lock the campaign (this week).**
- Land the pending individual-fixes commit (in flight).
- Commit an `ivtest_expected_divergence.list` consumed by the gate
  runner so the 11 policy items are machine-checked, making the
  standing criterion "**zero unexplained fork-only failures**".
- CI: add the vendored-ivtest name-diff gate to test.yml (it currently
  runs only the UVM sweep), so regressions are caught on every PR.

**Phase 1 — bounded tails (≈1 focused increment each).**
1. M12B-fr: VPI force/release on bit-selects + cbForce/cbRelease.
2. M12B rest: cbAssertionStart/Step/disable + attempt_info.detail.
3. M5-if: virtual-interface corners (incl. the modport continuous-assign ICE — the one remaining crash-class item).
4. M10B-md: multidim open arrays (svGetArrElemPtr2/3 walk).
5. M13B: bind-to-instance + timing-check tails + config disposition.
6. M7 stress: register-model + objections suites added to the UVM harness (defines "done" for M7).

**Phase 2 — big rock #1: M9-NFA** (multi-turn, staged behind a flag).
Thread-model → local vars → goto/nonconsec repetition → .matched/strong/
weak → multiclock. Retires the entire M9D backlog in one arc; lower risk
than the scheduler rock; assertion suite must be green at every stage.

**Phase 3 — big rock #2: M6-CALLF** (multi-turn, staged, race litmus
suite as gate). Unlocks in order: time-consuming DPI tasks → `expect`
→ cbNBASynch → **DPI export** (with the C-symbol trampoline). Do after
M9-NFA so the assertion engine is stable while the scheduler churns.

**Phase 4 — M1B endgame (interleaved + finishing arc).**
Mechanism: convert fallback sites bottom-up with the proven pattern
from this campaign (narrow the leniency → gate on what UVM actually
needs → four-gate verify → document). Sequence by risk-adjusted value:
elab_lval (8 sites, lvalue typing — highest silent-risk), netmisc (3
compile-critical stubs), elab_expr class-typing cluster (the 2 blocked
tests fall out here), then elaborate.cc's 21. Completion criterion:
every remaining fallback either deleted or emits a tracked diagnostic
code; sv_class_new_fail1 and func_empty_arg_fail4 pass; the
compile-progress grep count reaches zero in elab_lval/netmisc and only
documented, numbered diagnostics elsewhere.

**Closure definition.** The manifesto's end-state is reached when:
(a) all four gates green with zero unexplained fork-only failures
(Phase 0 makes this machine-checked); (b) M5-if/M10B/M12B/M13B tails
closed (Phase 1); (c) M9 and M6 fully closed by the two
rearchitectures (Phases 2–3); (d) M1B criterion met (Phase 4) — at
which point no compile-progress fallback can silently accept wrong
code, which is the manifesto's core promise held everywhere, not just
where tests look.


---

## Phase 4 progress ledger (2026-07-20)

Started, on branch `claude/ieee1800-uvm-implementation-qm5wad` (stacked on
PR #90). Working the elab_lval.cc lvalue-typing sites first (highest
silent-risk), bottom-up.

1. **darray/queue element bit/part-select stores** — DONE (PR #90). Two
   elab_lval.cc fallbacks retired: `d[i][b] = v` silently dropped the bit
   index and wrote the whole element (a live silent miscompile —
   `uvm_packer::unpack_bytes` does `value[i/8][i%8] = ...`), and
   `q[i][m:l] = v` aborted the compiler on an assertion in
   `elaborate_lval_net_part_`. Both now lower to a correct
   read-modify-write: the element-relative offset is normalized during
   elaboration (`normalize_variable_base`, so a run-time-variable index
   and non-zero-based element ranges both work) and carried as the lval
   part offset; tgt-vvp evaluates the word index and offset into integer
   registers and emits a new `%store/dar/vec4/off` vvp opcode that loads
   the element, splices the value, and stores it back — for dynamic
   arrays and queues (shared `vvp_darray` get_word/set_word base). Not-yet
   -lowered forms (compound assignment, indexed `+:`/`-:`, non-vector
   element) are loud sorries. Test: `tests/m1b_darray_elem_partsel_test.sv`.

Remaining elab_lval sites are the harder class-typing / aggregate cluster
(unpacked-struct member lvalue, assoc-array element property, unresolved
class property) — entangled with the elab_expr class-typing collapse
(finding 4, M1B parameterized dispatch), so sequenced after that per the
plan above.

Also on PR #90: the time-consuming DPI-export coroutine (ucontext) was
made POSIX-only via a single `IVL_NO_DPI_CORO` guard (`__MINGW32__ ||
__APPLE__`), fixing the macOS build (its SDK gates the ucontext routines
behind `_XOPEN_SOURCE`, unsatisfiable that late in the include order);
macOS now takes the same loud-sorry fallback as Windows.


---

## Phase 1 completion ledger (2026-07-18, post-hoc)

Phase 1 is COMPLETE. Per-item honest status:

1. **M12B-fr** (cbForce/cbRelease): done, merged (PR #81). VPI suite
   81 -> 83.
2. **M12B-rest** (cbAssertionStart/Disable/Enable/Reset via
   vpip_routines v4): done, merged (PR #81). cbAssertionStep remains a
   recorded corner.
3. **M5-if** (bare virtual iface decls, iface-member continuous
   assigns, generic-port sorry): done, merged (PR #81).
4. **M10B-md** (2-D/3-D DPI open arrays): done, merged (PR #81).
   DPI export remains future work (M10C with back-door DPI RAL).
5. **M13B** (bind-to-instance + instance lists, $timeskew/$fullskew/
   $nochange, edge-descriptor event lists, config hard error): done
   (PR #83).
6. **M7 stress** (register-model + objections suites): done — the
   suites exist, run in the sweep, and did their job by exposing six
   documented findings (m7_stress_findings_2026-07-18.md):
   - In the sweep and PASSING: m7_objection_stress_test (concurrent
     raise/drop, counted objections, phase held to t=80),
     m7_reg_model_semantics_test (structure/reset/desired-mirrored/
     predict/field-packing/map offsets), m7_ref_arg_copyout_test,
     inside_string_func_test, and reg_basic_test (user-backdoor RAL,
     UN-SKIPPED: its old "needs DPI" skip reason was wrong — finding 5).
   - FIXED during the campaign: finding 2 (ref/output copy-back lost
     with method-call sibling args — was silently no-opping the whole
     RAL front-door) and finding 5 (dup_expr type loss — was failing
     every backdoor access check).
   - Quarantined with loud pointers: tests/wip/
     m7_reg_frontdoor_stress_test.sv, blocked ONLY by finding 4
     (parameterized-class dispatch, M1B). Its address path is verified
     working end-to-end.
   - Recorded, with repros, for the next phases: finding 1
     (per-instance class events; blocks UVM post-run phases), finding 3
     ($unit-class timescale), finding 4 (parameterized dispatch),
     finding 6 (property access through indexed aggregate elements;
     blocks uvm_reg::get_address / by-offset predictor lookups).

Sweep at Phase-1 close: 198 passed / 0 failed / 0 skipped (no
KNOWN_FAIL entries remain). ivtest 44 expected failures, name-diff
clean; VPI 83/83; negative 43/43.

The honest bottom line: every Phase-1 construct tail is implemented
and verified; the M7 stress suites converted "register/objection
support is thin" from a vague label into six precisely-diagnosed,
reproducible defects, two of which are already fixed. UVM register
verification via user-defined backdoor works today; front-door needs
finding 4 (Phase 4 / M1B); uvm_hdl_* DPI backdoor is the planned M10C.
