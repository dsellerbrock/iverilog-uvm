# Automatic-variable storage refactor — working notes

Status: in progress (incremental migration).
Governing doc: `iverilog_ieee1800_uvm_manifesto.md`; root-cause writeup:
`test_suite_audit_2026-07-17.md` (search "automatic_events2").

## Models

**Upstream (9b44d55) single-task-frame model.** One activation frame
(`vvp_context_t`) per automatic *task/function call*, allocated by `%alloc
S_<task>` at the call site. Nested block/fork scopes inside the task get **no**
frame of their own: at vvp compile time, `vpip_peek_context_scope()` climbs
from any nested automatic scope to the outermost automatic ancestor, so every
nested-block local receives a context index *in the task frame*. Runtime is
trivially simple: an automatic-variable access is
`vvp_get_context_item(thread->rd_context, idx)` — the head of the thread's
context stack. `%fork` children in an automatic scope share the parent's
`wt_context` pointer; `do_join` only pops/pushes a context when joining a
task/function *call* thread. Limitation: `%join/detach` (join_any/join_none)
asserts if a detached child shares the parent's context — upstream simply does
not support detached forks inside automatic scopes.

**Fork per-block-frame model (being retired).** `PBlock::elaborate` wraps every
automatic *named* block/fork scope in `NetAlloc`/`NetFree`;
`vpip_peek_context_scope()` was changed to stop at `vpiNamedBegin`/
`vpiNamedFork`, so each block owns a frame. Because a parent-scope variable
reference can no longer assume "head of stack", a large heuristic layer was
added: scope-matched chain search (`vthread_get_rd_context_item_scoped`),
`automatic_context_owner`/`automatic_context_refcount` maps, context
sanitizing/recovery, and retain-on-detach in `%join/detach` (that last one is
what makes UVM's `fork…join_none`-in-automatic-tasks work — the reason the
model exists at all). The known cost: in a blocking `fork…join` inside an
automatic task, when one branch ends before a sibling reads a parent-scope
local, the shared parent context is dropped from the chain the sibling reads
through (ivtest `automatic_events2`; minimal repro below prints `r=x`,
upstream prints `r=a1`).

    task automatic w(input [7:0] id, output [7:0] r);
      begin: body
        reg [7:0] acc; acc = id;
        fork begin #10; end begin #30 r = acc; end join
      end
    endtask

## Where each side decides frame ownership (must stay in agreement)

1. **elaborate.cc `PBlock::elaborate`** — emits `NetAlloc`/`NetFree`
   (→ `%alloc`/`%free`) around a block's statements.
2. **vvp/vpi_scope.cc `scope_has_own_automatic_context_` /
   `vpip_peek_context_scope`** — compile-time: decides which scope's context
   receives each `.var`/`.array`/event item.
3. **vvp/vthread.cc `scope_has_own_automatic_context_` /
   `resolve_context_scope`** — runtime: same climb, but treats a named
   begin/fork as owning only if `nitem > 0` (i.e. only if compile time
   actually placed items there). This self-adapts: stop placing items in a
   scope and the runtime automatically climbs past it.

## Frame taxonomy

| Category | Own frame? | Why |
|---|---|---|
| automatic task/function (call site) | YES — keep | recursion; per-call locals |
| named `begin` w/ automatic parent scope | NO — **collapsed (step 1)** | statement completes before parent resumes; locals ride enclosing frame (upstream semantics) |
| named `begin` w/ *static* parent (block-local `automatic` vars in a static process) | YES — keep | no enclosing frame exists to ride |
| `fork…join` (blocking) scopes w/ automatic parent | NO — **collapsed (step 2)** | all branches complete before the parent resumes; locals ride enclosing frame |
| `fork…join_any`/`join_none` scopes | YES — keep | detached branches outlive the statement; frame lifetime managed by retain-on-detach refcounting |

## Step 2: collapse blocking fork/join scopes with automatic parents

The join type is known only to the front end (`PBlock::bl_type_`), so the
collapse decision is made once in `elab_scope.cc` (a new
`NetScope::auto_frame` flag: false for BL_SEQ/BL_PAR scopes with automatic
parents) and communicated end to end: `PBlock::elaborate` consults the flag
instead of recomputing; t-dll exposes it as `ivl_scope_auto_frame()`;
tgt-vvp emits collapsed scopes as `.scope autobegin.shared` /
`autofork.shared`; vvp's `compile_scope` parses the marker into
`__vpiScope::shares_parent_frame`, which `scope_has_own_automatic_context_`
consults for item placement. The runtime's `resolve_context_scope`
continues to self-adapt via its `nitem > 0` guard. This moved ivtest
`automatic_events`, `automatic_events2`, `automatic_events3` (formerly NI)
and `recursive_task` to gold.

## Step 1 (this change): collapse named begin blocks with automatic parents

- `elaborate.cc PBlock::elaborate`: emit the alloc/free prefix only when the
  scope is automatic AND NOT (BL_SEQ with an automatic parent scope). Collapsed
  blocks take the upstream path: `var_inits` elaborate inline into the block
  statement itself (which also restores the plain upstream path for
  constant-function evaluation — the staged `set_var_init` copy is only needed
  for frame-owning scopes whose initializers live in the scope-0 prefix).
- `vvp/vpi_scope.cc scope_has_own_automatic_context_`: `vpiNamedBegin` owns a
  context only when its parent scope is not automatic. (`vpiNamedFork`
  unchanged.)
- `vvp/vthread.cc`: **no change needed** — its `nitem > 0` guard self-adapts
  (collapsed begins receive no items).
- tgt-vvp: no change — `%alloc`/`%free` emission is driven purely by
  `NetAlloc`/`NetFree` statements.

Expected effects: `automatic_events2` (and the minimal repro) fixed because a
begin-block under an automatic task no longer manufactures a second frame, so
fork branches and their parent all read/write the one task frame, exactly as
upstream. `disable` of a named begin is unaffected (thread control, not frame
control). `fork…join_none` inside a collapsed begin still works: the detach
retain logic operates on whatever shared context the threads carry — now the
task frame instead of the block frame.

## Later steps

With per-block frames gone from the common paths, the eventual goal is to
retire the heuristic layer in vvp/vthread.cc (owner/refcount maps, scoped
chain search, sanitize/recovery) in favor of the upstream invariants,
keeping only the retain-on-detach mechanism that supports detached forks in
automatic scopes (the fork's genuine extension over upstream).

**Step 3 (first retirement pass, 2026-07-18).** A permanent engagement
census was added: `IVL_CTX_STATS=<file>` makes every recovery/repair/
fallback site append per-site counters at process exit (`ctx_stats_bump`
in vvp/vthread.cc). One full four-suite run on the collapsed model gave
this profile (aggregate hits):

| engaged (kept) | hits | | zero (retired) |
|---|---|---|---|
| rd-scoped.staged | 180k | | sanitize.wt/rd-changed (whole pass removed) |
| rd-scoped.wt-deep | 84k | | do_join transferred_context branch (no setter existed) |
| recover.miss | 83k | | ensure-write wt-deep / rd-fallback searches |
| recover.mismatch-repair | 62k | | of_FREE rd-deep + all next-rd searches |
| recv-sig.mismatch-repaired | 61k | | rd-scoped rd-deep / owned searches |
| free.wt-search | 34k | | recover static-scope thread fallbacks |
| alloc.staged-rd | 22k | | recv-sig.missing-recovered (never; recv-ev variant IS hit) |
| join.wt-caller-restore / pop-not-head | 7k/4k | | |
| free.null / free.skip / detach.retain-shared | 4k each | | |
| ensure-write.owned-fallback | 2.4k | | |
| recv-ev repairs, recover.nil-to-ctx | ~2k | | |
| rd-scoped.miss | 540 | | |
| alloc.scrub-wt/rd (context reuse while still chained) | 429 | | |

A second full-suite run after the retirements shows the identical profile
(and identical ivtest/UVM/VPI/negative results), with every retired-path
tripwire at zero.

**Step 4 (object-notification delivery, 2026-07-18).** Root cause of the
`recover.miss` (83k) / `recover.mismatch-repair` (62k) /
`recv-sig.mismatch-repaired` (61k) engagements, found by gdb backtraces at
the miss bump: `notify_mutated_object_root_` (fired by `%store/prop`,
`%store/qo*`, etc.) re-sends the mutated root object through the recorded
root net so object-valued waits re-evaluate — but it necessarily carries
the MUTATING thread's context, which is foreign to the receiving functor's
scope. The old recv path then "recovered" that context to the FIRST live
frame of the target scope (waking one arbitrary frame, silently missing
waiters in every other frame, and — worse — overwriting that frame's slot
with the notifying object even when it held a DIFFERENT object) or dropped
the delivery entirely on miss. Fixes:

- `vvp_fun_signal_object_aa::recv_object`: a context that is a live frame
  of the functor's own scope (checked via the exported
  `vthread_context_live_matches_scope`) takes the normal single-frame
  store path. Anything else is a notification: it now fans out to every
  live frame of the scope whose slot holds the SAME object (pointer
  identity), bumping only the mutation epoch — sibling frames holding
  other objects are untouched, and "no holder" is a legitimate no-op.
- `vvp_fun_anyedge_aa::recv_object`: foreign contexts skip the recover
  step entirely and take the existing per-context waiting-threads fanout
  (previously that fanout only ran on a recover MISS; a recover "repair"
  woke one arbitrary frame and missed the rest).

Full-suite results identical (ivtest set, UVM 180/0/1, VPI 81/81,
negative 32/32); the census after the fix: recover.miss 83k -> 277,
recover.mismatch-repair 62k -> 60, recv-sig.mismatch-repaired 61k -> 60,
recv-ev.* -> 0, replaced by honest counters: notify-unheld 111k (correct
drops), foreign-fanout 33k (correct multi-frame wakes), notify-fanout 84
(identity-matched deliveries).

**Step 5 (residue attribution, 2026-07-18).** The 277 remaining misses
fully attributed (scope-keyed census + gdb):

1. ~97 (ivtest `automatic_events*`, `automatic_task*` etc.): nil-context
   `vvp_send_vec4` from STATIC sources into automatic edge/anyedge event
   probes — by design, these take the per-context fanout where each
   frame's own edge state decides. The recover call before the fanout was
   pure noise (and its "repair" outcome — deliver to one arbitrary frame
   — never fired per census, which would have been a missed-wakeup bug if
   it had). The five fanout-shaped event recv sites (edge vec4, anyedge
   vec4/real/string, event-or) now use the explicit native-context check
   (`vthread_context_live_matches_scope`) and route everything non-native
   to the fanout; `vvp_named_event_aa` keeps its assert-native contract.
2. 180 (UVM, one per test): a VACUOUS static `$init` process that
   initializes `uvm_hdl_concat2string`'s struct-typed block-local
   (`uvm_hdl_path_slice slice = concat.slices[i]`, lowered to an
   anonymous cobj class) at t0 with no live frame — it loads the nil
   function argument, takes the null branch, and stores nil into a frame
   that does not exist (correctly dropped). ROOT CAUSE (found by
   pointer-tracing scope creation vs. the static-init decision):
   `elaborate_missing_package_function_scope_` in net_design.cc — the
   lazy materialization of a package function referenced (from
   already-elaborating class methods) before the package's function
   scope pass — created the FUNC scope without carrying the declared
   lifetime (`is_auto`), unlike its task-variant sibling. The
   materialized scope elaborated as static, so its nested blocks took
   the static var-init path and emitted the bogus `$init`; the later
   proper `elaborate_scope_func` pass created a second (correct) scope
   whose inline initializers are the ones the calls actually use. Fixed
   by setting `is_auto` on the materialized scope. After the fix,
   `recover.miss` and `rd-scoped.miss` are ZERO across the entire
   four-suite run.

After the event-side conversion the recover machinery has exactly three
remaining users: the vec4/real/string aa SIGNAL recv paths (near-zero
engagement), `set_root_provenance`, and `vvp_named_event_aa`'s
assert-native delivery.

**Retirement evidence so far (2026-07-18, post step 2).** With
`IVL_AUTO_CTX_WARN=1`: the local battery (frame-sharing, recursion x100
depth-500 with frame reuse, join_none churn with 400 detached branches,
disable, static-parent blocks, const funcs) triggers ZERO recovery paths on
the refactored build. UVM (`configdb_assoc_test`) still triggers five —
recv-object-aa / recv-anyedge-object-aa repairs, an owned-context %free
fallback in `uvm_topdown_phase.traverse`, and a nil-context scoped read in
`uvm_hdl_concat2string` — but the IDENTICAL five fire on the unmodified
main build (114cdbc), so they are pre-existing engagements of the
object/event propagation paths, not artifacts of the collapse. Conclusion:
the thread-context recovery machinery is no longer exercised by
block/fork/recursion control flow, but the object/event-callback paths
(recv-*-aa) still lean on it; those need their own root-cause pass before
any wholesale retirement.
