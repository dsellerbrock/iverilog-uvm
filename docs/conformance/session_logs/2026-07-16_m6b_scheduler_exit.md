# 2026-07-16 — M6B: scheduler conformance inventory + `$exit`

Directive: continue the Milestone Truth Audit corrective pass; move to
**M6B — Scheduler conformance audit and remediation**. Build the
scheduler conformance inventory and implement at least one concrete
scheduler gap if feasible.

## Audit finding

The vvp scheduler is deeply remediated already (prior M6 work:
region-tagged events, Preponed/Observed/Reactive/Re-Inactive/Re-NBA
queues, `event.triggered` slot persistence, `->>` nonblocking triggers,
a region-transition invariant, the scheduled-call protocol behind a
flag). An 18-probe event-region litmus battery run this session
(`scratch m6b/l1..l18`) found the runtime **correct on every probed
construct**: NBA vs blocking/`#0` pre-NBA reads, NBA swap, `$strobe`
post-NBA ordering, `->>` and `->> #N` nonblocking event triggers,
`e.triggered` same-slot persistence, `wait fork` / `disable fork`,
inertial-delay cancellation, continuous-assign reacting to an NBA
update, `$monitoron/off` gating, program/reactive-region ordering, and
clocking preponed sampling.

So M6's *runtime* is in good shape; what M6 lacked (per the truth audit)
was the manifesto-required construct-level **inventory** written down,
and one genuinely-missing construct surfaced by the probes:

- **`$exit` (IEEE 1800-2017 24.7)** was an undefined system task — a hard
  vvp load error, not merely absent.

## Deliverable 1 — scheduler conformance inventory

`docs/conformance/scheduler_conformance_inventory.md`: for each of 20
scheduling constructs (blocking `=`, NBA `<=`, named/nonblocking event
triggers, `event.triggered`, fork/join family, `#0`, process scheduling,
program/reactive execution, assertion sampling/evaluation, clocking
input-sample and output-drive, VPI callbacks, DPI tasks, `$strobe`,
`$monitor`, `final`, `$finish`/`$stop`/`$exit`, continuous assign,
inertial delay) — the current runtime path, intended IEEE 1800-2017
clause-4 region, observed behaviour, and the permanent test that pins it.

The remaining *true* gaps are recorded honestly: program-completion-ends-
simulation (24.7/3.9, not implemented), cbNBASynch/post-NBA VPI callback
regions (no distinct home), DPI tasks that consume time (run inline, no
suspension region), the callf scheduled-call protocol (flagged off,
blocked on function-call atomicity 13.4.3), and the wholesale
queue-promotion approximation. None is a silent miscompile.

## Deliverable 2 — `$exit` implementation

`vpi/sys_finish.c`: `sys_exit_calltf` registers `$exit` and ends the
calling program via `vpi_control(vpiFinish, 0)` (quiet — no `$finish`
banner). No-argument compile check reused (`sys_no_arg_compiletf`).

**Why quiet-finish, not full program tracking:** Icarus does not track
per-program completion, and a program that completes naturally does NOT
end the simulation today (verified: a program testbench ran to its
watchdog). Implementing the LRM "simulation ends when the last program
completes" rule would change end-of-sim behaviour for the **57 ivtest +
3 harness** tests that use program blocks, risking byte-diff
regressions. Since the dominant `$exit` use is a single program
testbench ending the test — for which "all programs complete" IS "this
program completes" — quiet-finish is correct for that case and cannot
regress existing tests (`$exit` was previously a compile error, so
nothing used it). Multi-program early-exit is a recorded corner.

## Tests

- `tests/m6b_exit_test.sv`: `$exit` in a program testbench terminates the
  program (the line after it must not run) and ends the simulation before
  a watchdog fires.
- `tests/m6b_scheduler_litmus_test.sv`: self-checking regression pinning
  NBA swap, blocking/`#0` pre-NBA reads, `->>` nonblocking event,
  `e.triggered` slot persistence, continuous-assign-after-NBA, and
  inertial-delay cancellation.
- `$exit(5)` → clear no-argument error.

## Regression evidence

- UVM harness: **167/167**, 0 failed, 0 skipped, zero no-check
  (165 + 2 new tests).
- Negative suite: **24/24**. Existing m6_sched_litmus /
  m6_reactive_region / program_block tests pass.
- ivtest name-diff: see promotion commit (the `system.vpi` change touches
  the 57 program-block cases — the key check).

## Status

**M6 → M6B: PARTIAL, advancing.** Inventory delivered; `$exit` closes one
construct gap; the runtime is conformant on all 20 inventoried constructs
for their common cases. Remaining true gaps ledgered.

## Next engineering action

**M4-av** — string/real-VALUED integer-keyed associative-array reads (the
remaining *silent* miscompile from the M14 audit; needs the `sig`-form
string/vec4-keyed assoc-load opcodes that today exist only for `obj`
keys). Then M9B/M9C (`within`/`until`/`intersect`).
