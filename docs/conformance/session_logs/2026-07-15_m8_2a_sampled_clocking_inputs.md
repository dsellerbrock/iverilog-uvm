# 2026-07-15 — M8 increment 2a: sampled clocking-block inputs (14.13)

Directive: "Fix M4 until it is full closed then move onto M8
Increment 2." M4 was closed and promoted earlier today (see
2026-07-15_m3_m4_m5_closeout.md). This log covers the first M8-2
increment: real input-sampling semantics for clocking blocks,
replacing the alias model (`cb.sig` reading the raw signal live).

## Semantics implemented

IEEE 1800-2017 14.13: clocking-block inputs are sampled at the
clocking event with the default #1step skew — the value the signal
held at the START of the edge's time step (the Preponed-region
value). Between clocking events the clockvar holds the most recent
sample. Explicit skew VALUES are still accepted-and-discarded
(recorded for 2d); outputs keep the alias model until 2b.

Visibility model (deterministic, race-free):
- The sample variables update in the NBA region of the edge time
  step (IEEE puts clockvar updates after Active — we use NBA rather
  than Observed; indistinguishable to user code, and 2b output
  drives want the NBA machinery anyway).
- A process woken by the RAW edge (`@(posedge clk)`) reads the
  PREVIOUS sample in the Active region — the strict-LRM answer, and
  the reason the LRM recommends waiting on `@(cb)` instead.
- A process waiting on `@(cb)` is woken by a nonblocking trigger the
  sampler fires AFTER its NBA stores, so it reads THIS edge's
  samples. `##N` default-clocking waits use the same event.
- Before the first clocking event, input clockvars read X (matches
  common commercial behavior).

## Mechanism

- **parse/pform (2a-1)**: clocking_item rules record direction per
  signal (input/output/inout; the combined `input ... output ...`
  form records inout) into Module::PClocking; copied into
  netclass_t::clocking_block_t for interface types.
- **vvp (2a-2)**: `vvp_wire_vec4` (the filter both `.var` and `.net`
  carry) grows an opt-in 1-deep driven-value history: on the FIRST
  change in a time step it snapshots (prev value, time). New opcodes:
  - `%hist/on <sig>` — enable history (idempotent; emitted in the
    sampler prologue, which runs at time 0 before any edge).
  - `%load/preponed <sig>` — push the Preponed value: prev if the
    signal changed during the current step, else the current value.
    Degrades to the current value for non-vec4 filters.
  Known limitation: the history tracks the DRIVEN value, so a signal
  under an active force samples its pre-force value (recorded).
- **elaboration (2a-3)**:
  - elab_sig creates, per instance with sampleable inputs (vec4
    scalars): `_ivl_smp$<cb>$<sig>` REG vars (type copied from the
    raw signal) and the `_ivl_smptrig$<cb>` named event. Created in
    the SIGNAL pass so references from anywhere (including
    `inst.cb.sig` from parents) resolve during elaboration.
  - elaborate synthesizes per clocking block:
        initial begin
          $ivl_clocking_hist_on(raw1); ...
          forever @(<clocking event>) begin
            _ivl_smp$cb$sig1 <= $ivl_clocking_sample(raw1); ...
            ->> _ivl_smptrig$cb;
          end
        end
    ($ivl_clocking_sample → %load/preponed; $ivl_clocking_hist_on →
    %hist/on; both lowered in tgt-vvp.)
  - PEventStatement elaboration redirects `@(cb)` / `@(inst.cb)` to
    the trig event when it exists (blocks with no sampled inputs
    keep the underlying-event substitution).
  - The shared netmisc.cc rewrite helpers gained a read/write mode:
    READS of input/inout clockvars rename the signal component to
    the sample var (when it exists — unsampleable signals keep the
    alias, so routing and sampling stay consistent by construction);
    WRITES to input clockvars are errors (14.3) with elaboration
    continuing on the alias path. The vif class path
    (rewrite_class_clocking_member_path) stays alias — 2a-4.
  - Non-vector (real/string) and array clocking inputs: sorry
    message at elaborate_sig, alias behavior retained (recorded).

## The general `->>` fix (IEEE 1800-2017 15.5.1)

The sampler uses a nonblocking event trigger, which turned out to be
BROKEN in vvp and papered over with a tgt-vvp sorry ("->> is not
currently supported"): tgt-vvp emitted `%event/nb`, and vvp's
of_EVENT_NB called schedule_propagate_event(), which sends the value
out of the event net's OUTPUT to its fanout — but threads waiting on
a named event hang off the functor's waitable hooks, woken only by a
delivery to port 0 (what blocking `%event` does via vvp_send_vec4).
So `->>` compiled, warned, and then silently never woke anyone.

Fix: of_EVENT_NB now schedules a port-0 delivery via
schedule_assign_vector(ptr, 0, 0, X, delay, thr->is_reactive_process)
— the NBA region, or Re-NBA from reactive (program) threads so a
trigger issued after a program thread's NBA stores observes them
(this ordering was caught by g01's program-block check). The stale
sorry in tgt-vvp is removed; `->>` and `->> #delay` now work
generally.

## Debug notes (for future archaeology)

- First cut used blocking stores + blocking trigger. tests/
  clocking_test.sv exposed the race: vvp's event wait list is a
  LIFO stack rebuilt each cycle, so an `@(posedge clk)` reader and
  the sampler wake in alternating order — reads of cb.data were
  nondeterministic. NBA stores + NB trigger made both reader classes
  deterministic (and match the LRM region model).
- The program-block variant then failed (pcb.pin = xx): NBA stores
  from a reactive thread go to Re-NBA, but the trigger went to plain
  NBA — firing BEFORE the stores. Hence the is_reactive_process flag
  on the trigger scheduling.
- Sweep-procedure trap (cost one aborted sweep pair): the UVM
  harness and ivtest resolve `which iverilog`/`which vvp`. Run with
  PATH=/home/user/iverilog-install/bin:$PATH (UVM) or the ivtest
  shim PATH. Without it, every test COMPILE_FAILs instantly.

## Tests

- tests/m8_clocking_sample_test.sv — 13 checks: sample holds between
  edges; the same-time-step blocking-write-before-edge race is
  closed (#1step takes the previous step's value); @(cb) readers
  deterministically see the waking edge's sample; inout clockvars
  sample; pre-first-edge reads are X; output alias write unchanged.
- tests/negative/m8_clocking_input_write.sv — `cb.din <= v` rejected
  with a 14.3 diagnostic (negative suite now 11).
- tests/clocking_test.sv — updated to strict 14.13 semantics
  (@(bif.cb) instead of @(posedge clk) before reading bif.cb.data);
  exercises the interface-instance path end to end.
- tests/g01_module_clocking_test.sv — header updated; all 9 checks
  still pass (its reads sample stable values), including the
  program-block clocking check that caught the Re-NBA ordering bug.

## Evidence

- Focused battery: m8_clocking_sample, g01, clocking_test, m4_closeout,
  g26 interface ports, g35 ordering, g09 store2, m3 dynforeach,
  m3 solve...before, g71 — ALL PASS. Negative suite 11/11.
- Full UVM harness + ivtest sweeps: PENDING at WIP-commit time;
  results recorded in the promotion note below when complete.

## Promotion evidence (2a-1..2a-3 + the ->> fix)

- UVM harness (PATH-corrected rerun): **138 passed / 0 failed /
  0 skipped, zero "(no-check)" entries** (137 prior +
  tests/m8_clocking_sample_test.sv).
- ivtest (shim PATH, same checkout/list as baseline):
  Total=2559 Passed=2456 Failed=100 — failure names identical to
  fails_baseline.txt except `pow_ca_signed`, the documented
  load-timeout flake (verified standalone: PASSED, 24.3s wall against
  the 25s shim; fails under sweep load). No ->>-related ivtest
  deltas in either direction.
- Negative suite 11/11.

The WIP commit (M8-2a sampled inputs + ->> fix) is hereby promoted —
regression-clean.

## 2a-4: the virtual-interface (class) path

`vif.cb.sig` reaches the clocking block through a class-typed handle;
the bound interface instance is only known at run time. Mechanism:

- The interface CLASS type registers the hidden sample variables as
  properties (`_ivl_smp$cb$sig`, plus a `_ivl_smptick$cb` bit). The
  vvp runtime resolves interface properties BY NAME in the bound
  instance scope (vvp_vinterface::find_named_item_), where
  elaborate_sig created exactly those signals — so a property read
  lands on the per-instance sample variable with no new runtime
  machinery. Only sampleable inputs (vec4, non-container) get
  properties; unsampleable ones keep the alias rewrite on both the
  elaboration and class sides, consistent by construction.
- rewrite_class_clocking_member_path gained the same read/write mode
  as the scope helpers: reads rename the signal component to the
  sample-var property; writes to inputs are 14.3 errors.
- `@(vif.cb)`: a named event cannot be reached through a class
  handle, so the sampler toggles the tick bit via NBA AFTER its
  sample stores (initialized to 0 in the prologue — ~x is x and an
  x->x toggle would never fire an anyedge). The event elaboration
  maps @(vif.cb) to an ANYEDGE wait on the tick PROPERTY, riding the
  existing %wait/vif edge-functor machinery from the M5 work. NBA
  FIFO ordering (stores, then toggle) gives @(vif.cb) waiters the
  same fresh-sample contract as the module path.

### Second general `->>` bug found: nodangle deleted ->>-only events

NetEvent::ntrig() counts only BLOCKING triggers (the trig_ list);
nonblocking triggers live on the separate nb_trig_ list. nodangle's
event-liveness test (nwait + ntrig + nexpr == 0) therefore DELETED
any event whose only reference is a `->>` statement, and code
generation segfaulted on the dangling pointer
(dll_target::proc_nb_trigger -> lookup_scope_ on freed memory). This
fired the moment a sampler's trig event had no @(cb) waiters (the
vif test waits via the tick property instead). Fix: new
NetEvent::nnb_trig() joins the liveness sum. Together with the
port-0 delivery fix, `->>` is now usable end to end for the first
time: it previously compiled with a sorry, never woke waiters, and
crashed codegen if nothing else referenced the event.

### Tests

- tests/m8_vif_clocking_sample_test.sv — sampling through a virtual
  interface in a class: hold between edges, #1step same-step-write
  race, @(vif.cb) fresh-sample contract, instance-path/vif-path
  agreement.
- tests/negative/m8_vif_clocking_input_write.sv — vif.cb.din <= v
  rejected (14.3); negative suite now 12.

## Promotion evidence (2a-4 + nodangle ->> liveness fix)

- UVM harness: **139 passed / 0 failed / 0 skipped, zero "(no-check)"
  entries** (138 prior + tests/m8_vif_clocking_sample_test.sv).
- ivtest (shim PATH): Total=2559 Passed=2457 Failed=99 — failure
  names BYTE-IDENTICAL to fails_baseline.txt (empty diff; no flakes
  this round).
- Negative suite 12/12; focused battery 10/10.
- PR #75 CI on the 2a-4 head: MINGW64 failed in MSYS2 pacman setup
  (mirror flake, exit 8 before compiling — the documented recurring
  infra failure); all other platforms in progress/green at check
  time. The promotion push retriggers CI.

The WIP commit (M8-2a-4) is hereby promoted — regression-clean.
**M8 increment 2a is COMPLETE across all three clocking-block access
paths (same-scope, instance, virtual interface).** Next: 2b
synchronous output drives.

## 2b: synchronous output clockvar drives (14.16)

`cb.out <= v` previously wrote the raw signal immediately (alias).
Now:

- elab_sig creates `_ivl_obuf$cb$sig` (drive buffer, raw's type) and
  `_ivl_opend$cb$sig` (pending bit) per OUTPUT/INOUT clockvar, and
  the tick/trigger machinery is synthesized for outputs-only blocks
  too (previously only blocks with sampled inputs got a sampler).
- PAssignNB::elaborate intercepts plain NB drives whose l-value is a
  same-scope `cb.sig` or instance `inst.cb.sig` OUTPUT/INOUT
  clockvar and emits: buffer store, then
  `if ($ivl_clocking_sample(tick) !== tick) raw <= obuf; else
  opend = 1;` — the tick comparison (1-deep history, tick toggles in
  the NBA of each event step) answers "did the clocking event already
  occur in this step". Drives after an @(cb) wake land in the same
  step (the LRM's drive-at-current-event case); drives between events
  buffer.
- A synthesized apply process per block lands buffered drives at each
  clocking event, woken by the sampler's trigger (NBA region → the
  apply runs after Active, Re-NBA-like timing; it also catches
  same-step drives that raced the edge in Active):
  `initial forever @(trig) if (opend) begin raw <= obuf; opend=0; end`
- 14.16.2 last-drive-wins falls out of the buffer (later stores
  overwrite).
- Fall-through to the alias NBA (recorded): vif.cb.out drives (needs
  a preponed-through-property mechanism), part-selects of clockvars
  (14.16.2 partial drives), intra-assignment controls (`<= ##N` is
  2c), unsampleable signals.

Test: tests/m8_clocking_drive_test.sv (between-edge buffering,
same-step drive after @(cb), last-drive-wins, inout drive/sample
interaction incl. the pre-drive #1step sample at the landing edge,
instance paths). g01 (module + program output drives) and
clocking_test (instance-path drive) pass unchanged on the new
semantics.

## Promotion evidence (2b)

- UVM harness: **140 passed / 0 failed / 0 skipped, zero "(no-check)"
  entries** (139 prior + tests/m8_clocking_drive_test.sv).
- ivtest (shim PATH): Total=2559 Passed=2457 Failed=99 — failure
  names BYTE-IDENTICAL to fails_baseline.txt (empty diff).
- Negative suite 12/12; focused battery 12/12.

The WIP commit (M8-2b buffered output drives) is hereby promoted —
regression-clean.

## 2c: cycle-delayed clocking drives `cb.out <= ##N v` (14.16)

Previously a syntax error. New grammar rules
(`lpvalue K_LE K_CYCLE_DELAY delay_value_simple expression` and the
`##(expr)` form; bison conflict counts unchanged at 458 s/r,
1053 r/r) lower the drive at parse time via
pform_make_clocking_drive to the EXISTING intra-assignment
repeat-event shape:

    lval <= repeat (N) @(<clocking prefix of lval>) v;

which has exactly the right semantics for free: the value is
captured when the statement executes; the update fires after N
occurrences of the clocking event; overlapping in-flight drives are
independent (each NBA event carries its own captured value;
last-wins only when landing at the same event); and the @(cb) event
control goes through the clocking machinery — including the
sampler-trigger redirect — so the landing is ordered after that
event's input sampling (post-NBA, Re-NBA-like timing), consistent
with 2b's plain drives.

Limitation (diagnosed sorry, recorded): the scalar default-clocking
form `x <= ##N v` needs default-clocking resolution at elaboration
time; only the clockvar-prefix form is lowered.

Test: tests/m8_clocking_cycle_drive_test.sv — ##1 lands at the next
edge (not immediately), ##2 two edges out, RHS captured at issue
time (later RHS changes don't affect the in-flight drive), two
overlapping ##2 drives land independently at their own edges.

## Promotion evidence (2c)

- UVM harness: **141 passed / 0 failed / 0 skipped, zero "(no-check)"
  entries** (140 prior + tests/m8_clocking_cycle_drive_test.sv).
- ivtest (shim PATH): Total=2559 Passed=2457 Failed=99 — failure
  names BYTE-IDENTICAL to fails_baseline.txt (empty diff).
- Negative suite 12/12; focused battery 13/13.

The WIP commit (M8-2c cycle-delayed drives) is hereby promoted —
regression-clean. M8 increment 2 status: 2a (input sampling, all
paths), 2b (output drives), 2c (##N drives) COMPLETE; 2d (skew
application, clocking_decl_assign, global clocking 14.14/G59) is the
remaining tail, plus the recorded fall-through corners.
