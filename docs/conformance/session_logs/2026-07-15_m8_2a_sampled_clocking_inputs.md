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
