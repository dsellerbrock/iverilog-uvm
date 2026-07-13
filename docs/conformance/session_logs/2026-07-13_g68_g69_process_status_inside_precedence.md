# Session log — 2026-07-13 (second target): G68 process.status + G69 inside precedence

Engineering target (forced by regression): the class-property receiver
checkpoint (c6e8206) turned three UVM tests red on a quiet machine —
seq_trace_test / vif_smoke / vif_smoke_v2, all SEQLCKZMB@0 +
PH_TIMEOUT@9200.  Root-caused to TWO pre-existing latent defects that
the receiver work exposed by making the sequencer's zombie predicate
actually execute for the first time.

## Root-cause chain (evidence)

1. Structural image diff (pointer-normalized) between def4cf7 and
   c6e8206: 8 `find_with: bad arg shape` fallbacks became real loops —
   including `uvm_default_factory.m_resolve_type_name_by_inst` and
   `uvm_sequencer_base.grant_queued_locks` (the function that emits
   SEQLCKZMB).
2. grant_queued_locks zombie predicate:
   `arb_sequence_q.find(item) with (item.request==SEQ_TYPE_LOCK &&
   item.process_id.status inside {process::KILLED,process::FINISHED})`.
3. **G68**: `status` was declared as a stored property on the built-in
   process class (elab_type.cc) that nothing ever wrote — and the
   compile-progress method-stub classifier ALSO listed `status` →
   constant 0.  0 == FINISHED in the 9.7 enum.
4. **G69**: `%right '?' ':' K_inside` put inside at ternary precedence,
   so the predicate parsed as `((request==LOCK && status) inside
   {KILLED, FINISHED})` — for any non-lock entry the short-circuit
   yields 0, and `0 inside {4, 0}` is TRUE.  Confirmed by reading the
   emitted bytecode (the `%cmpi/e 4` / `%cmpi/e 0` comparisons applied
   to the padded && result).  An env-gated runtime trace
   (IVL_PROC_TRACE) proved `%process/status` never even executed —
   every zombie match came from the short-circuit path.
5. Every arbitration entry became a "zombie" at t0; lock sequences
   were removed; the phase never advanced; PH_TIMEOUT@9200.

## Implemented

- **G68** (IEEE 1800-2017 9.7): new vvp opcode `%process/status` —
  pops a process handle, pushes the live state via
  `vvp_process::status()` (FINISHED=0, RUNNING=1, WAITING=2,
  SUSPENDED=3, KILLED=4; nil handle pushes x).  Elaboration lowers
  both the call form (`p.status()`, elab_expr.cc method dispatch) and
  the paren-less property-chain form (`item.process_id.status`, the
  class-property tail walker) to `$ivl_process$status`; the
  compile-progress stub classifier exempts process.status; tgt-vvp
  dispatches it in draw_sfunc_vec4 (draw_eval_object + opcode).
  `process::FINISHED/RUNNING/WAITING/SUSPENDED/KILLED` now also bind
  in module scope (route added before the unbindable-identifier
  fallback, which WARNED AND DROPPED the expression).
  Known approximation (recorded in the audit): delay-suspended
  processes read RUNNING; SUSPENDED is never reported (no
  suspend()/resume()).
- **G69** (IEEE 1800-2017 Table 11-2): K_inside moved from the
  ternary `%right` group to the relational `%left` group in parse.y.
  Grammar conflicts unchanged (459 s/r, 1060 r/r).
- Env-gated `IVL_PROC_TRACE` diagnostics kept in of_PROCESS_SELF /
  of_PROCESS_STATUS (matches the project's IVL_*_TRACE pattern).

## Tests

- `tests/g68_process_status_test.sv` — enum constants, self RUNNING,
  live/killed/finished children, and the exact UVM zombie-predicate
  shape (live req not zombie, dead req is zombie, non-lock dead-proc
  req not zombie — the case the && guard must protect).
- `tests/g69_inside_precedence_test.sv` — inside vs && (both truth
  values plus the short-circuit case that distinguishes the
  mis-parse), inside vs ==, inside vs || and ?:.

## Regression evidence

Recorded in the checkpoint commit message (UVM suite incl. the three
previously-red tests, bundled ivtest, negative 6/6, focused
m6/g12/m3 re-runs, all G10 probes).
