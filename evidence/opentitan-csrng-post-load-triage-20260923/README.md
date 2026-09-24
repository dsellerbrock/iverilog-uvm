# CSRNG post-load stall triage (2026-09-23)

The selected CSRNG smoke image and runtime arguments are recorded exactly in
`progress.json` and `counters.json`; they come from the patched, disposable
FuseSoC fileset in `../opentitan-csrng-blklen-overlay-20260923/smoke-replay.json`.
This investigation used the current installed Icarus binaries only. It did
not alter the image, released OpenTitan sources, or compiler/runtime source.

`vvp -n` was sampled for 13 seconds. `vvp -v -n` and two debugger attaches
showed that VVP linked the image and entered `schedule_simulate`. The process
consumed about one CPU and 295 MB RSS, but produced no UVM report. Its hot
path was `generic_event_s::run_run` -> `vvp_fun_concat8::run_run` ->
`vvp_send_vec8`, often continuing through `reduce4` or a part select.
`attach.json`, `sample-4s.txt`, and `sample-12s.txt` preserve these stacks.

The more decisive observation is that the process is still **propagating
initialization events**, before simulation starts. At the third bounded
attach, LLDB read `sim_started = 0` and a non-null `schedule_init_list`
(`phase.lldb.log.gz`). `schedule_simulate()` drains that list before setting
`sim_started = true` and before `vpiStartOfSim()` or the scheduler proper
(`vvp/schedule.cc:1676-1715`). A `schedule_functor()` callback made during
this phase appends another event to the same list (`vvp/schedule.cc:1431-1456`).
The zero-UVM observation therefore is not merely output buffering or a
post-start testbench wait.

Three debugger samples at 3.514, 6.965, and 10.410 wall seconds all read
simulation time 0 and just one time event, while `count_gen_events` rose from
9,764,563 to 32,769,998 to 56,130,398 (`counters.json`). The initializer
propagation is not converging within the 120-second coordinator bound. The
existing `IVL_SAME_TIME_LIMIT=100000` watchdog also timed out in a separate
10-second check (`watchdog.json`): it guards the later scheduler time-cell
loop, not this earlier initialization-list loop. This is a localization, not
yet proof of which net, generated VVP edge, or source construct causes the
feedback.

The bounded read-only LLDB trace in `trace_lldb.py` mapped all 449 compiled
`.concat8` functors to their VVP labels and stopped after 5,000 concat
executions. Four labels accounted for 4,769 of those executions
(`concat_identity.json`): `L_0x7636d62e90` and `L_0x7636d59470` are the
`cmd_req` packed structs of `tb.csrng_if[0]` and `[1]`; `L_0x7636d407e0`
is the testbench's `csrng_cmd_req` packed-array connection; and
`L_0x7636e84880` is `tb.dut.u_csrng_core.genbits_stage_rdy`.
The first two feed the latter two. Their source path is the unchanged released
`csrng_if.sv:15,30-47` and nested `push_pull_if.sv:94-106`, then
`tb.sv:81-94` and `csrng_core.sv:1043`. A second 1,000-hit trace
(`concat_values.json`) found that the two interface `cmd_req` values repeat
between an all-`e6` raw vector8 encoding and an `00`/`e6` mixture;
`vvp_scalar_t` uses `00` for high impedance. The recurrence shows active
signal-value oscillation, not merely repeated scheduling of a stable output.

`packed_tri_feedback.sv` is the cheap paired RED. It retains a single packed
struct field and the two conditional tri-state drivers from the interface
path. With `FEEDBACK=1`, both editions compile but fail to reach `#1` within
two seconds; LLDB on the 2017 image again reads `sim_started=0`, sim time 0,
and 11.8 million generic events (`packed_tri_feedback.json`,
`red_attach.lldb.log`). With `FEEDBACK=0`, the same pin driver and packed
field reach `#1` and print `PASS control reached time one: 1` in both
editions. A scalar feedback probe and an acyclic packed-interface probe also
pass in both editions (`scalar_tri_feedback_probe.json`,
`packed_interface_probe.json`). Thus the pre-start oscillation needs the
packed field plus the conditional resolved feedback, not an arbitrary
`concat8` or scalar feedback path.

The narrow implementation question for the coordinator is why the packed
field/resolver/MUXZ feedback alternates between X and Z before procedural
initialization when the two-state mode bits default to zero. Preserve normal
value-change propagation and field resolution while making this feedback
converge; do not treat a watchdog or dropped event as a functional pass.

## Post-filter replay and scheduling boundary

The coordinator installed a candidate `vvp_wire_vec8::filter_vec8` equality
guard. Its four focused tests passed, but the exact configured CSRNG image
still produced no UVM report after 120 seconds. A new 8.6-second sample on
VVP SHA `6f85134f9ed5b7609a2bedc2bae9e1a926966932acf63485e0ebeabeed5ad111`
shows the **same** pre-start loop: at 5.57 and 8.57 seconds `sim_started=0`,
simulation time is 0, the initialization list is non-null, and generic-event
counts are 1,387,913 and 17,266,313 (`postfix_profile.json`). The bounded
1,000-hit trace reproduces the same four hot labels and X/Z pattern
(`postfix_concat_identity.json`). This is no evidence of DV progress.

The original frozen RED and the broader two-interface RED also still time out
in both language editions on that VVP (`postfix_reducers.json`). The first
ivtest convergence fixture had changed `(if_mode == 1'b0/1'b1)` into
`!if_mode/if_mode`. That compiles to direct select connections rather than
the XNOR gates in the frozen RED, so its prior green result did not validate
the pinned failure. The fixture now preserves the exact comparisons;
`postfix_faithful_ivtest_red.json` records the paired RED.

The gate matrix isolates the `if_mode == 1'b1` comparison feeding the packed
field MUXZ: retaining it still times out, while replacing both mode compares
with direct bit tests reaches `#1` (`postfix_gate_matrix.json`). In a second
matrix, constant `if_mode` values 0 and 1 each reach `#1`, but a declaration
initializer `bit if_mode = 1'b1` still cannot reach `#1`. Initializing all
interface variables in their declarations makes the design reach `#1`
(`postfix_mode_matrix.json`). Those observations identify a time-zero
initialization-order dependency; they do not license changing the logic or
assuming an arbitrary execution order.

The next source boundary is the VVP scheduler. `schedule_simulate()` drains
`schedule_init_list` to quiescence before setting `sim_started=true` and
running time-zero threads, and `schedule_functor()` appends newly generated
events back to that same list. IEEE 1800-2017/2023 §§4.5 and 4.9.1 require
initialization events and continuous assignments at time zero; a dynamically
growing pre-start queue must not starve the time-zero procedural assignment.
Any scheduler change requires separate ownership and tests for event-order,
initial-value, and feedback behavior. The vec8 equality guard alone is not a
fix for this pinned smoke.

The first standalone VPI startup boundary incorrectly required a continuously
assigned wire to be resolved in `cbStartOfSimulation`. The coordinator's
paired run reached that callback but reported the wire unpropagated
(`/tmp/ivl-focus-20260923/csrng-startup-vpi/result.json`). Under IEEE
1800-2017 §§38.36.3, 4.5, and 4.9.1, that callback begins the time-zero
cycle; the continuous assignment executes within the cycle. The revised
boundary checks callback order, handle validity, and the two-state variable
default there, then checks direct and forwarded wire values after `#1`.

The first watchdog probe used an `always` process whose only timing control
was `#0`; Icarus correctly rejected it at compile time as a process without
delay. A second probe using one `always @(toggle)` process reached `#1`,
because a process cannot retrigger itself before rearming. Both are invalid
oracles for a genuine oscillation. The current probe uses two cross-coupled
event processes and starts its first edge from an inactive-region `#0`
assignment, after both processes have subscribed. It should never reach its
`#1` fatal if zero-time oscillation is properly left active or diagnosed by
`IVL_SAME_TIME_LIMIT`.
The paired coordinator run with `IVL_SAME_TIME_LIMIT=10000` does emit
`Watchdog: 10000 events at sim time 0 ps -- bailing out` and never reaches
`#1`. VVP exits 0 after this watchdog, so process status alone cannot be
treated as a pass; the diagnostic and absence of a success marker are the
negative oracle. The watchdog's exit status is a separate diagnostic
limitation, not part of this scheduler fix.
