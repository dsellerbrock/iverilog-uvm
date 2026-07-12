# CURRENT WORK — continuation file

Keep this accurate enough that another session can resume without repeating
the investigation. Update at every meaningful checkpoint.

## State as of 2026-07-11 (session: typed-expression dispatch)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy`
- **Latest pushed commit**: `51c0d94` (checkpoint 2 — M1 implementation, tests, vvp fix)
- **Pull request**: https://github.com/dsellerbrock/iverilog-uvm/pull/66 (draft; CI watched)
- **Final regression evidence**: UVM 104/104; ivtest byte-identical to pristine
  baseline (vvp_reg 2961/3101 + same 132 pre-existing fails, vpi 85/85,
  vvp_reg.py 284/12); make check pass; negative suite 2/2.
- **Selected feature**: Manifesto M1 — typed-expression method dispatch
  (gaps G22, G31, G32 + latent vvp same-scope frame bug)
- **Governing IEEE clauses**: 1800-2017 8.10 (object methods), 6.19.5 (enum
  methods), 8.23 (class scope resolution), 8.25 (parameterized classes),
  13.4.1 (void functions / discarded results)

## Completed this session

1. Manifesto imported at `docs/conformance/iverilog_ieee1800_uvm_manifesto.md`.
2. Baseline: clean build + 98/98 canonical UVM regression at `a014332`.
3. **Parser** (`parse.y`):
   - `expr_primary '.' IDENTIFIER/TYPE_IDENTIFIER argument_list_parens` no
     longer deletes the receiver: PEIdent receivers splice into a
     hierarchical path (behavior-preserving); all other receivers become
     receiver-carrying `PECallFunction`s.
   - New `subroutine_call` alternatives for statement-context chains:
     `f(args).m(args);`, `C::get(args).m(args);`, `C#(p)::get(args).m(args);`
     (+2 shift/reduce conflicts, resolved by shift = the new rules; baseline
     448 → 450 s/r, r/r unchanged at 1060).
4. **AST**: `PECallFunction` and `PCallTask` carry an optional `receiver_`
   expression (`PExpr.h/cc`, `Statement.h/cc`, `pform_dump.cc`).
5. **Elaboration** (`elab_expr.cc`):
   - Extracted the method-dispatch tail of `elaborate_expr_method_` into
     shared `elaborate_method_dispatch_(sub_expr, target_type, ...)`.
   - New `elaborate_receiver_method_` elaborates the receiver, takes its
     exact `net_type()`, and dispatches (class methods incl. inherited &
     specialized, enum methods, string/queue/darray methods).
   - `PECallFunction::test_width` handles receiver calls (mirrors
     `PEMemberAccess::test_width`).
   - `PCallTask::elaborate_receiver_method_` (`elaborate.cc`): class-typed
     receivers; void methods/tasks via `elaborate_build_call_`; non-void
     via PAssign-to-nothing re-expression.
6. **vvp runtime fix** (`vvp/vthread.cc`,
   `vthread_get_rd_context_item_scoped`): after a callf join, the returned
   child frame (rd-head, no longer in the wt chain) now takes priority over
   a same-scope pre-%alloc'd caller frame at wt-head. Fixes nested calls of
   the SAME function (builder chains `c.f(...).f(...)`, `f(g(f(x)))`).
   **This bug pre-existed this session's work** — confirmed by pristine
   baseline build failing the reduced probe.
7. **Tests added** (committed to `tests/`):
   - `m1_method_on_call_result_test.sv` (f().method(), f().prop, void stmt)
   - `m1_method_chain_builder_test.sv` (chains + nested same-method)
   - `m1_enum_method_chain_test.sv` (enum_f().name(), c.next().name(), …)
   - `m1_static_accessor_chain_test.sv` (S::get().m(), P#(T)::get().m(), stmt)
   - `m1_uvm_factory_by_name_test.sv` (G22 unmodified-UVM flow)
   - `tests/negative/` + `run_negative.sh` (unknown method on call result,
     unknown enum method → controlled diagnostics)

## Tests currently passing

- All six reduced probes (originally 5 failing shapes).
- UVM factory by-name probe (G22 canonical path) — PASS.
- Negative suite 2/2.
- Canonical regression: rerun in progress at last update (baseline was 98/98).

## Known limitations / follow-ups

- Statement-context chains cover single-hop `<call>.method(args);` for the
  three grammar shapes above. Multi-hop statement chains
  (`f().m1().m2();`) and receiver forms starting from casts/selects in
  statement position are not yet parsed. Expression context covers
  arbitrary depth.
- Diagnostics for failing receiver calls print twice (test_width +
  elaborate double elaboration — same pre-existing pattern as
  PEMemberAccess).
- Non-class receivers in statement context get a clean `sorry`.
- `with`-clause locator methods on receiver calls parse to PENull
  (pre-existing parser fallback, unchanged).

## Checkpoint 4 (M3) — regression-clean, PR #67

- **G15/G17/G18/G20 FIXED + G11 implication half**: constraint implication,
  if-else sets, enum-literal sets, inheritance merge, and solver arithmetic
  (impl/iff/add/sub/mul/div/mod). See session log checkpoint 4.
- PR #66 (M1+M2) was MERGED into main; branch restarted from merged main.
- M3 work on PR #67 (draft): WIP commit `9d64dda` + regression-confirmation
  docs commit.
- Regressions: UVM **110/110**; ivtest **byte-identical to baseline**
  (2961/3101+132, 85/85, 284/12); make check pass.

## Checkpoint 5 (M3 increment 2) — regression-clean

- **G21 FIXED**: `arr.size()` → solver size var `s:N:T`; darray created/
  resized at write-back (cap 65536), elements filled randomly.
- **G16 FIXED (static arrays)**: PEConstraintForeach + compile-time unroll
  with loop-var env; element vars `e:N:W:I` solved and written back;
  %randomize now fills static-array rand property elements.
- **Hang fixed**: solver inside/dist range parser now expression-capable
  and always makes forward progress (previously hung on compound ranges).
- Focused: single-shot probes + 10-iteration probe + permanent test
  `tests/m3_constraint_array_test.sv` all PASS. UVM regression
  **111/111**; ivtest **byte-identical to baseline**. WIP marker on
  6f7e875 superseded by the regression-confirmation docs commit.

## Exact next actions

1. Watch PR #67 CI (Ubuntu/macOS green earlier; MSYS2 re-running after
   the checkpoint-5 push).
2. Remaining M3 tail: dynamic-array foreach (solve-time template
   expansion after the size var fixes), signed comparisons in the IR,
   `solve...before` staged ordering, non-0-based array ranges.
3. Alternatives per manifesto sequence: M4 container runtime, M5
   interfaces/modports (Phase 70), M6 scheduler audit, or G66 root-cause.

## Manifesto v2 alignment review (2026-07-11)

The governing manifesto was updated to v2 (commit c2e53d3). Review of this
session's M1-M3 implementations against v2:

- **Semantic IR remediation**: the M1 receiver-dispatch work matches v2's
  prescribed migration entry point (expression and member-access
  semantics). `elaborate_method_dispatch_` is the shared typed-expression
  dispatch interface; return types flow through `NetEUFunc(net_type)`.
- **Code-pattern scan** of the full session diff: no added TODO/FIXME,
  no compile-progress fallbacks, no UVM identifier checks; one explicit
  `sorry` diagnostic (non-class receivers in statement context) per
  manifesto principle 4.
- **Tracked diagnostics added** (v2: "convert silent type-recovery
  fallbacks into tracked diagnostics"): unrepresentable-constraint-item
  warning; uarray shape-mismatch errors.

### Architectural debt register (v2 Risks)

1. **PEIdent path-splice adapter** (parse.y receiver rules): legacy
   name-based lookup retained for identifier receivers. Acceptable
   adapter now; must not become a permanent duplicate dispatch path
   (fold into receiver dispatch when the semantic IR migration reaches
   name resolution).
2. **test_width double-elaboration** (receiver calls, PEMemberAccess
   pattern): duplicate diagnostics; symptomatic of missing typed
   expression interface (v2 Risk 4).
3. **vvp automatic-context heuristics** (`staged_alloc_rd_*`,
   `skip_free_*`, chain-membership fix): the returned-frame fix is
   correct but the surrounding machinery relies on implicit ordering —
   squarely in v2's scheduler remediation program scope (M6 audit item 4/5:
   direct thread execution + synchronous-child assumptions in callf).
4. **Constraint IR is string-based S-expressions** with unsigned-only
   comparisons and scalar-only properties: adequate for current gaps,
   but array/signed/ordering support (G16/G21) will strain it; consider
   a typed constraint IR when extending.
5. **Pre-existing compile-progress fallback inventory** (45 sites,
   audit section) remains open — Phase 75 scope.

## Decisions not to revisit without new evidence


- Receiver dispatch reuses `elaborate_method_dispatch_` — do NOT fork a
  second dispatch path for receiver calls.
- PEIdent receivers in the changed parser rules must keep path-splicing
  (preserves package/implicit-this resolution semantics).
- The vvp fix keys on "rd-head live for scope AND absent from wt chain";
  the %alloc staging window keeps wt-head priority because the caller
  frame is still chained in wt. Both cases are exercised by
  `m1_method_chain_builder_test.sv`.
