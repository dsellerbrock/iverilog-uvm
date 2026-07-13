# CURRENT WORK — continuation file

Keep this accurate enough that another session can resume without repeating
the investigation. Update at every meaningful checkpoint.

## State as of 2026-07-13c (session: 7.12.2 ordering methods)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy` (PR #69 open,
  draft).
- **This checkpoint**: three defects in the sort/rsort/reverse/
  shuffle/unique statement paths (IEEE 1800-2017 7.12.2): instance-
  property receivers silently NO-OP'd (explicit skip in
  tgt-vvp/vvp_process.c — now hidden-recv-net pattern, matching the
  expression-side G10 work); with-clause sort keys always truncated
  to int32 (string keys — the UVM `sort() with (item.get_full_name())`
  shape in uvm_cmdline_report/uvm_root/uvm_phase_hopper — silently
  mis-sorted past a shared 4-byte prefix; keys now typed
  string/real/sb32 end to end); shared iterator-net poisoning in the
  sort_with elaboration (now fresh nets + set_signal_alias).
  Runtime: qsort/qunique keys helpers generalized over key type — no
  new opcodes.
  Details: `session_logs/2026-07-13_g10_ordering_methods.md`.
- **Tests**: `tests/g10_ordering_methods_test.sv` (28 checks).
- **Remaining 7.12 tail**: unique on non-queue receivers;
  assoc/multidim receivers; `item.index`; fixed-array class
  properties; ordering methods on fixed-size arrays.

## State as of 2026-07-13b (session: G68 process.status + G69 inside precedence)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy` (PR #69 open,
  draft).
- **Regression alert resolved**: checkpoint c6e8206 (property
  receivers) turned seq_trace_test / vif_smoke / vif_smoke_v2 red
  (SEQLCKZMB@0 + PH_TIMEOUT@9200) by making the UVM sequencer zombie
  predicate execute for the first time, exposing TWO pre-existing
  latent defects, both now fixed:
  - **G68**: `process::status()` read a dead stored property (always
    0 = FINISHED per 9.7) — now a live query via new vvp opcode
    `%process/status` (call form + paren-less property-chain form +
    stub-classifier exemption + module-scope process:: enum
    constants).
  - **G69**: `inside` sat at ternary precedence; Table 11-2 puts it
    at the relational level — `a && b inside {c,d}` mis-parsed as
    `(a && b) inside {c,d}`, so `(0) inside {KILLED, FINISHED=0}`
    matched every non-lock arbitration entry.  K_inside moved to the
    relational %left group (conflicts unchanged 459/1060).
  Details: `session_logs/2026-07-13_g68_g69_process_status_inside_precedence.md`.
- **Tests**: `tests/g68_process_status_test.sv`,
  `tests/g69_inside_precedence_test.sv`.
- **Known approximation**: delay-suspended processes read RUNNING;
  SUSPENDED never reported (no suspend()/resume()).

## State as of 2026-07-13 (session: G10 tail — class-property receivers)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy` (PR #69 open,
  draft; CI green on all 6 platforms at def4cf7 before this
  checkpoint).
- **This checkpoint**: array reduction/min-max/find* methods now work
  on CLASS-PROPERTY receivers — the dominant UVM shape
  (`this.q.sum()` in scoreboards, `cfg.st.q.max()` nested chains,
  external `obj.q.sum()`, paren-less `return q.sum;`).  Mechanism: a
  non-signal object receiver is evaluated once and its handle stored
  into a hidden container-typed net that the existing inline loop
  indexes through (extra trailing sfunc parm; tgt-vvp
  `draw_array_method_recv_`).  The PEIdent class-property tail path
  that previously WARNED AND SILENTLY DROPPED the expression
  (`Array method 'sum' on class-property darray/queue not yet
  supported ... expression dropped`) now routes to the same
  machinery.  Fixed-size-array class properties: explicit sorry.
  Details: `session_logs/2026-07-13_g10_property_receivers.md`.
- **Tests**: `tests/g10_array_methods_test.sv` extended to 43 checks
  (class-property section: method-internal, external, nested-chain,
  paren-less, with-clause, locators, empties).
- **G10 tail remaining**: sort/rsort/reverse/shuffle (7.12.2); unique
  on non-queue receivers; assoc/multidim receivers; `item.index`;
  fixed-size-array class properties.

## State as of 2026-07-12e (session: G10 array reduction methods)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy` (PR #69 open,
  draft — this checkpoint stacks onto it; head before this checkpoint
  was 9f7c918, the ivl.def Windows export fix).
- **This checkpoint**: G10 — IEEE 1800-2017 7.12.3 array reduction
  methods (`sum`/`product`/`and`/`or`/`xor`) and 7.12.1
  `min()`/`max()` implemented over queues, dynamic arrays and 1-D
  fixed-size unpacked arrays, in all four source forms (call,
  call+with, paren-less, paren-less+with) including the keyword-named
  `.and()/.or()/.xor()` (new grammar rules, +6 documented s/r
  conflicts 453→459).  `find*` locators extended to dynamic/fixed
  arrays.  Result width/signedness follow the with expression
  (7.12.3).  New `NetScope::set_signal_alias` gives each call its own
  iterator binding (7.12 "scope for the iterator_argument is the with
  expression") — also fixes a pre-existing find_with bug where sibling
  calls with different element types shared one hidden `item` net
  (signed/width poisoning; could trip a vvp store assertion).  Runtime
  is inline vvp loops from EXISTING opcodes only
  (`$ivl_darray_method$reduce|`/`minmax|` lowered in tgt-vvp).
  Explicit `sorry` diagnostics (no silent fallbacks) for assoc-array
  and multidimensional receivers and string/real min/max.
  Details: `session_logs/2026-07-12_g10_array_reduction_methods.md`.
- **Tests**: `tests/g10_array_methods_test.sv` (29 checks incl. all
  7.12.3 LRM literal examples);
  `tests/negative/g10_reduction_non_integral.sv` (negative suite now
  6/6).
- **G10 tail remaining**: sort/rsort/reverse/shuffle (7.12.2); unique
  on non-queue receivers; assoc/multidim receivers; `item.index`;
  class-property receivers (still on the older PEIdent property path).

## State as of 2026-07-12d (session: M6 item 2 — Reactive region)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy`, restarted from
  merged main (PR #68 merged with G67 + G12 static/dynamic streaming —
  do not reopen; this checkpoint gets a NEW draft PR).
- **This checkpoint**: M6 scheduler remediation item 2 — program-block
  processes now schedule in the Reactive region set (IEEE 1800-2017
  4.4.2.5/.6/.7, clause 24): new vvp slot queues reactive/re-inactive/
  re-nbassign with LRM promotion order; per-thread reactive flag from
  the new `.scope program` type (plumbed via new ivl_scope_program API),
  inherited by spawned children; program #0 → Re-Inactive; program NBAs
  → Re-NBA; event wake chains PARTITIONED by region (a shared functor
  previously dragged all waiters into one region).  Both elaborate.cc
  program-scheduling compile-progress warnings retired.  Programs now
  sample post-NBA design state race-free.
  Details: `session_logs/2026-07-12_m6_reactive_region.md`.
- **Tests**: `tests/m6_reactive_region_test.sv` (4 region orderings).
- **Regressions**: UVM 118/118 (+1 new test); ivtest 2961/3101 with the
  same 132 pre-existing fails (baseline-identical).
- **Known approximation** (recorded in scheduler audit): wholesale
  queue promotion (pre-existing model) — exact region-priority popping
  is item 1's region-tagging work.
- **Next options**: M6 items 1 (region tagging + trace) / 4
  (Preponed/Observed stubs) / 5 (scheduled-call protocol); G12 tail
  (struct operand flattening, with[range]); M3 tail; G66; G09/G10.

## State as of 2026-07-12c (session: G12 tail — dynamic-size streaming)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy` (PR #68 open,
  draft — three checkpoints stacked).
- **This checkpoint**: dynamic-size streaming operands/targets
  (11.4.14.4) implemented via a vvp runtime stream builder — new
  opcodes `%stream/flatten/{obj,str}`, `%stream/end/{l,r}`,
  `%stream/unpack/{l,r}`, `%stream/to/{queue,dar}`, plus
  `get_bitstream` overrides for queue/string containers.  Both UVM
  idioms verified end to end (uvm_reg_map byte<->bit queue pair
  round-trips bit-exactly; uvm_misc string-queue join).  Previously
  all these shapes compiled cleanly with silent wrong data.
  Unsupported dynamic contexts now error with clause references.
  Details: `session_logs/2026-07-12_g12_dynamic_streaming.md`.
- **Tests**: `tests/g12_streaming_dynamic_test.sv`.
- **G12 tail remaining**: `with [range]`, continuous-assign streaming
  lvalues, struct/class operand flattening, class-property container
  operands, multi-operand dynamic unpack.

## State as of 2026-07-12b (session: G12 streaming concatenation)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy` (PR #68 open,
  draft — this checkpoint stacks onto it).
- **This checkpoint**: G12 fixed for fixed-size integral operands —
  multi-operand streaming concatenation pack AND unpack (IEEE
  1800-2017 11.4.14/.1/.2/.3), removing the parse.y fallback family
  that silently dropped operands.  Semantics grounded in the published
  LRM text and its literal examples (all in the permanent test).  Key
  subtleties implemented: unpack is the INVERSE of the `<<` reorder
  (differs from forward when slice ∤ width), wider unpack sources are
  consumed from the left, pack-as-assignment-source is LEFT-aligned
  with error on narrower targets, slice sizes (expressions/types)
  resolve at elaboration.  Details:
  `session_logs/2026-07-12_g12_streaming_concatenation.md`.
- **Tests**: `tests/g12_streaming_concat_test.sv` (+2 negative tests).
- **G12 tail (recorded in gap audit)**: dynamic-size operands
  (queues/darrays/strings, 11.4.14.4 — needed by uvm_reg_map byte
  packing), `with [range]`, continuous-assign streaming lvalues,
  struct/class operand flattening.

## State as of 2026-07-12 (session: G08 event.triggered + G67 process identity)

- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy`, restarted from
  merged main (`439ba47`, PR #67 merged — do not reopen; new work gets a
  NEW draft PR).
- **This checkpoint**: G08 `event.triggered` (IEEE 1800-2017 15.5.3) is in
  main via PR #67; the two UVM regressions it exposed
  (`vif_smoke`/`vif_smoke_v2` PH_TIMEOUT) were root-caused to **G67**:
  `vthread_new` never initialized `is_fork_v_child`, so
  `process::self()` inside fork...join_none blocks could alias an ancestor
  process (heap-garbage dependent), and UVM's phase kill then destroyed
  sibling phase processes (driver run_phase died mid sequencer handshake).
  Fix: one line in `vvp/vthread.cc` (`thr->is_fork_v_child = 0;`).
- **Evidence**: byte-identical compiled images differing in one label
  string flipped hang/pass pre-fix; the previously-failing image passes
  unmodified on the fixed runtime. Full chain in
  `session_logs/2026-07-12_event_triggered_g67_process_identity.md`.
- **Tests added**: `tests/m6_process_identity_test.sv` (+ G08's
  `m6_event_triggered_test.sv` from the merged PR).
- **Gap audit**: G08 FIXED, G67 NEW+FIXED (docs/claude gap audit updated).
- **Next recorded options** (unchanged priority list): M6 remediation items
  1/2/4/5 (region tagging + trace hook; Reactive region for program
  blocks; Preponed/Observed stubs; scheduled-call protocol replacing callf
  synchronous-drain heuristics — G67 is more evidence this area needs it);
  M3 tail (dynamic-array foreach, solve...before staged ordering,
  non-0-based foreach ranges); M4 container runtime; M5
  interfaces/modports; G66 root-cause.

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

## Checkpoint 6 (M3 tail: signed comparisons) — regression-clean

- Unary minus folded to two's complement (was silently dropped);
  signed p:/e: markers; bvslt-family + sign extension per IEEE
  1800-2017 11.8.1; signed inside/dist ranges.
- Test `tests/m3_constraint_signed_test.sv`. UVM **112/112**; ivtest
  **byte-identical to baseline**. WIP 889d084 superseded.

## Checkpoint 7 (M6 scheduler audit) — docs + litmus regressions

- `docs/conformance/scheduler_audit_2026_07.md`: queue inventory
  (start/active/inactive/nbassign/rwsync/rosync/del_thr + init/final
  lists), IEEE 4.4.2 region mapping (Preponed/Observed/Reactive ABSENT),
  implicit-ordering inventory (%fork push_flag, insertion-order
  dependence), direct-execution findings (callf synchronous drains and
  the staged-context heuristics), event-trigger lifetime (G08),
  VPI callback mapping, end-of-slot behavior, and a 5-step remediation
  priority list for M6 implementation.
- `tests/m6_sched_litmus_test.sv`: NBA-vs-blocking, #0 inactive, and
  $strobe postponed-region orderings as durable characterization
  regressions (PASS).

## Exact next actions

1. Watch PR #67 CI.
2. M6 implementation per the audit's remediation priorities: (1) region
   tagging + trace hook, (2) Reactive region for program blocks,
   (3) slot-persistent event.triggered (G08), (4) Preponed/Observed
   stubs, (5) scheduled-call protocol replacing callf sync drains.
3. Remaining M3 tail: dynamic-array foreach, `solve...before` staged
   ordering, non-0-based array ranges.
4. Alternatives: M4 container runtime, M5 interfaces/modports, G66.

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
