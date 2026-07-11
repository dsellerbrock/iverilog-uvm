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

## Exact next actions

1. Watch PR #66 CI (6 jobs: Ubuntu 22/24, macOS, MSYS2 MINGW64/UCRT64/CLANG64);
   fix any platform-specific fallout (most likely candidates: C++ dialect
   nits in the new elab code, or MSYS2 grammar rebuild differences).
2. Next milestone per manifesto sequence — M2 remainder: G25
   (`uvm_field_sarray_int` copy/clone field automation) and G23
   (`uvm_register_cb` class-layout corruption). Start by rerunning probes
   p72/p28 shapes as reduced language tests; G24 config-db already passes
   (test committed); G22/G31/G32 closed.
3. Then M3 constraint solver (Phase 66 scope: G11/G15/G16/G17/G18/G20/G21).

## Decisions not to revisit without new evidence

- Receiver dispatch reuses `elaborate_method_dispatch_` — do NOT fork a
  second dispatch path for receiver calls.
- PEIdent receivers in the changed parser rules must keep path-splicing
  (preserves package/implicit-this resolution semantics).
- The vvp fix keys on "rd-head live for scope AND absent from wt chain";
  the %alloc staging window keeps wt-head priority because the caller
  frame is still chained in wt. Both cases are exercised by
  `m1_method_chain_builder_test.sv`.
