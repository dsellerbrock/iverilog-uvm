# VVP multicore scheduling: bounded Adams Bridge assessment

## Decision

Do not start parallel `vthread_run()` on the current VVP image. The target has enough useful work for a *coarse* two-core task, but no certified ready batch in the current interpreter. A first parallel stage must be an opt-in, compiler-certified Active-region **prepare** task: read a stable signal snapshot, compute RHS values, and append nonblocking-assignment intents to a private log. The scheduler then replays those intents in original process/event order and continues draining Active before entering NBA. Keep VPI callbacks, DPI calls, UVM/class mutation, derived-clock/Active feedback, and any unproved process on the serial path.

The first serial-shadow experiment now exists in this isolated branch. It proves a narrow NBA intent-log boundary for one ordinary no-fork `always_ff` body; it does not create a read snapshot or a parallel-ready task. For Adams Bridge, the compiler must also form one macro-task from each lane's parent/child fork/join sequence before the 46 lanes become a ready batch. This is an architectural prerequisite, not a safe `std::thread` wrapper around existing dispatches.

## Isolated serial-shadow result

With `IVL_SHADOW_NBA_CERTIFY=1`, `tgt-vvp/vvp_process.c` marks only an `always_ff` containing one ordinary edge wait and one or two zero-delay, whole-vector NBAs. The RHS can be only a fixed static integral signal or a literal. All other statement and expression kinds, selectors, automatic scopes, and program scopes stay on the normal path. The certificate rejects a function-call RHS, a delayed NBA (`x <= #1 a`), and a `$display` task in separate compile probes. An additional event control inside `always_ff` fails elaboration under the language rule. Without the compile flag, the image has no marker.

With `IVL_SHADOW_NBA=1`, VVP runs the certified process serially and collects its allocated NBA event objects in a private log. It appends them to the existing NBA queue, in order, before another Active event runs. An unexpected scheduled event, delayed NBA, or Reactive NBA during this dispatch aborts as a violated certificate. Without the runtime flag, the ordinary dispatch path is used. No worker threads, queue-region changes, or shared-branch compiler edits are involved.

The focused regression `sh profiling/run_shadow_nba.sh` passes. The pre-change compiler fails its required `$shadow_nba` marker check. The current 2012 image emits one certified thread; 2017 and 2023 focused compiles also emit the marker and pass the callback ledger. The ordinary and serial-shadow VPI logs match exactly: `0001 → 1001` at 1 ns, then `1111 → 0000` at 3 ns. Shadow trace shows two NBA intents at each edge. `profiling/shadow_nba.expected` records each callback separately, so merging or reordering the two NBAs fails. The rejected effects are tested as separate top modules, so one rejection cannot mask another.

Seven alternating env-off pairs on the identical bounded 100-clock Adams Bridge image compare the profiler-only `0de6270ba` VVP with this prototype. Median wall time is 312.941 ms versus 312.640 ms; median CPU is 311.401 ms versus 311.258 ms. Median paired ratios are 0.9951 wall and 0.9951 CPU, with the same `hash=cc373498` and empty stderr on every run. The small difference is measurement noise, not evidence of a speedup. `profiling/shadow-vs-profiler-only-overhead.json` holds each pair.

This is still a serial interpreter run: the RHS reads live VVP signals in original process order, and the intent log only delays NBA queue insertion until the same dispatch returns. Parallel prepare needs an explicit stable input snapshot, machine-readable read/write footprints, proof that no source can mutate those inputs within a batch, and an uninterrupted certified Active-ready group. The current Adams Bridge fork/join ordering fails that last condition. This prototype stays private until those boundaries have controls.

## Measured work

The bounded test is `work/caliptra-perf/real_a2b_diag_tb.sv`, WIDTH=46, 100 stimulus cycles. The existing `real-a2b-ready-summary.json`, `real-a2b-ready.stderr.log`, and `real-a2b-ready-overhead.json` were reused; the 100-slot ready trace was not repeated.

| Measurement | Result |
|---|---:|
| Plain VVP median wall / CPU, seven runs | 308.920 / 307.534 ms |
| Diagnostic VVP median wall / CPU, seven runs | 350.028 / 348.647 ms |
| Ready-trace overhead | 13.3% wall, 13.4% CPU |
| Median events / vthread dispatches per positive-edge slot | 6,851.5 / 894.5 |
| Median peak queued vthreads per positive-edge slot | 137 |
| Median summed vthread execution per positive-edge slot | 1.898 ms |
| Dispatches under 0.5 µs | 65,980 / 90,557 = 72.9% |
| Dispatches at least 20 µs | 4,544 / 90,557 = 5.0% |

Across all 205 time slots in the ready trace, timed vthread execution sums to 192.777 ms; the diagnostic run's median CPU is 348.647 ms. If **all** vthread time could be split perfectly, Amdahl estimates ceilings of 1.38× on two cores and 1.71× on four, before worker overhead. These are estimates from timed code in a diagnostic build, not measured multicore results or proof that this work is independent. The other 586,000 event dispatches and signal propagation remain serial in a thread-only design.

I profiled one existing steady slot at 195,000 ps with `IVL_BATCH_PROFILE_TIME=195000` in this isolated clone. The output hash stayed `cc373498`. The profiler logged exactly 894 vthread dispatches, totaling 2.049 ms of timed execution (instrumented sample). Of this, 46 x/y pipeline child bodies take 1.088 ms, median 23.6 µs each; 46 sum pipeline child bodies take 0.445 ms. Together these 92 bodies consume 1.533 ms, 74.8% of that slot's timed vthread work. They are separated by parent join/resume dispatches in the exact repeating order `sum child → parent → x/y child → parent`, lane 45 down to 0. The largest contiguous run of these heavy children in the recorded dispatch sequence has length one. `batch-profile-summary.json` records per-lane costs.

The isolated `vvp/schedule.cc` change implements opt-in, one-slot task-cost profiling via `IVL_BATCH_PROFILE_TIME`; env-off VVP retains the ordinary dispatch path. The next implementation slice adds conservative compiler metadata for pure no-fork process footprints, then checks for a contiguous certified Active-ready group before trying serial shadow prepare/commit. Keep costs grouped by certified macro-task, not by every tiny dispatch.

Seven alternating env-off pairs against the pre-instrumented VVP built from the same `216dd6dc1` source and flags show no material default-path cost: median wall 316.055 ms before versus 316.094 ms after, median CPU 314.678 versus 314.882 ms. The median within-pair ratios are 0.9974 wall and 0.9978 CPU; these small differences are measurement noise. Every run kept `hash=cc373498`, and the env-off stderr log is empty. `env-off-overhead.json` holds the paired samples.

A standalone persistent-worker no-op rendezvous on this Mac costs a median 3.4–3.6 µs for two cores and 7.3–7.4 µs for four cores (two runs, 10,000 samples each; p90 6.6–6.9 and 10.6–10.8 µs). This excludes VVP state isolation, log merge, cache contention, and fallback checks. It rules out moving the 72.9% sub-0.5-µs dispatches individually; a 0.5-ms certified payload per positive-edge slot would be large enough to make a two-core prototype worth measuring. The observed 1.533-ms lane payload clears that work threshold, but fails the present semantic-certification/batching gate.

## Why the existing VM cannot run those bodies concurrently

The static VVP image has one 4,232-bit `x_reg`, one `y_reg`, and one `sum_reg` object. Forty-six process bodies each target the same x/y object identities, and another 46 target the same sum object. Their `%assign/vec4/off/s2` bases are `0, 92, …, 4140`, matching disjoint logical 92-bit lane slices. This is potential *logical* parallelism, not physical thread safety. `vvp_fun_signal4_sa::recv_vec4_pv` mutates the same `bits4_` object and sends the whole packed vector after each partial NBA update; that propagation can trigger processes and VPI callbacks. NBA publication must therefore stay serial and in the original event order.

The event queue drains Active, ActiveSync, Inactive, NBA, Observed, Reactive, Re-NBA, and callback regions in order. `%fork` and `%join` call `schedule_vthread(..., true)`, which inserts zero-delay work at the front of Active. Deferring a child while continuing its parent would change ready order. `vthread_run()` also uses global `running_thread` and global trampoline state; many opcodes enqueue into the global scheduler. DPI/VPI and UVM class/random state need explicit effect certification, not an assumption that separate SV process scopes imply thread safety. This simple RTL sample has only the testbench `$display`/`$finish` VPI calls and no UVM/DPI, so its passing hash does not qualify those wider boundaries.

## Transfer from Verilator

[Verilator's internals](https://github.com/verilator/verilator/blob/master/docs/internals.rst) describe `V3Order`'s fine-grained dependency graph, `V3Partition`'s contraction to a few dozen macro-tasks, static assignment of tasks to workers, and cache-line-aware variable placement. Those are the transferable ideas. The same document says its earlier dynamic graph follower performed poorly. [Thread PGO](https://verilator.org/guide/latest/simulating.html) measures macro-task cost and feeds it back into partitioning; VVP should likewise gather per-macro-task cost after semantic certification. Verilator's [DPI threading policy](https://verilator.org/guide/latest/exe_verilator.html) distinguishes pure and non-pure imports; VVP's first stage should reject both until its own ABI and callback rules are audited.

VVP's dynamic stratified queue is not Verilator's statically ordered `eval()` DAG. Transfer the dependency proof, coarse cost balancing, and static worker assignment; retain VVP's event-region transitions and serial observable effect order.

## Next gate and controls

1. In a compiler-only experiment, annotate a no-fork `always_ff` body with exact read set, thread-local writes, NBA destinations and packed-bit ranges. Reject VPI, DPI, class/randomization, blocking writes to shared objects, event controls, timing controls, forks, and unknown target offsets. Form a contiguous Active-ready group with no intervening uncertified event.
2. Run the group's prepare code **serially** with private NBA intent logs. Compare signal snapshots, intent order, event-region transitions, and per-update VPI callback observations against legacy VVP. Include disjoint and overlapping packed writes, an NBA-triggered derived clock, a fork/join case that stays serial, four-state values, an impure DPI call, and a UVM/class mutation that stays serial.
3. Only when the serial shadow agrees, enable two persistent workers for certified prepare groups. Merge intents in original sequence, then test one/two/four cores on the same bounded image with seven paired runs and identical output hash plus event/VPI ledger. A practical go criterion is at least 0.5 ms certified payload on ≥90 of 100 positive edges and at least 5% median end-to-end speedup with no bit/event-order difference. If Adams Bridge remains ineligible, teach the compiler to collapse its lane-local parent/child fork/join into one certified macro-task; keep generic dynamic forks serial.

No two- or four-core VVP benchmark is claimed here because no safe parallel execution path has been enabled.

The focused `sh profiling/run_nba_vpi_order.sh` control already passes on this isolated VVP. Its VPI callback logs `0001 → 1001` for two disjoint partial NBAs at 1 ns and `1111 → 0000` for overlapping whole-vector NBAs at 2 ns. A prepare/commit implementation that coalesces updates or reorders them fails the four-line expected log, even if the final vector is correct.

## Reproduce the focused measurements

Build VVP from this isolated branch with the local `libffi` and Z3 include/library paths, then run:

```sh
IVL_BATCH_PROFILE_TIME=195000 vvp/vvp /Users/danielellerbrock/Documents/Codex/2026-09-27/users-danielellerbrock-projects-iverilog-uvm-handoff/work/caliptra-perf/real_a2b_diag-fused.vvp > profiling/batch-profile.stdout.log 2> profiling/batch-profile.stderr.log
python3 profiling/summarize_batch.py profiling/batch-profile.stderr.log profiling/batch-profile.stdout.log
python3 profiling/static_footprints.py /Users/danielellerbrock/Documents/Codex/2026-09-27/users-danielellerbrock-projects-iverilog-uvm-handoff/work/caliptra-perf/real_a2b_diag-fused.vvp
clang++ -std=c++11 -O2 -pthread profiling/barrier_microbench.cc -o profiling/barrier_microbench
profiling/barrier_microbench 2
profiling/barrier_microbench 4
sh profiling/run_nba_vpi_order.sh
python3 profiling/compare_env_off.py /Users/danielellerbrock/Documents/Codex/2026-09-27/users-danielellerbrock-projects-iverilog-uvm-handoff/work/caliptra-perf/compiler-proto/vvp/vvp vvp/vvp /Users/danielellerbrock/Documents/Codex/2026-09-27/users-danielellerbrock-projects-iverilog-uvm-handoff/work/caliptra-perf/real_a2b_diag-fused.vvp
```

The env-off VVP run also produced `hash=cc373498` with zero profiler lines on stderr. The profile instrumentation is confined to this isolated branch.

For the serial-shadow control, build the full local compiler and VVP with Homebrew Bison on this Mac (`make -j8 YACC=/opt/homebrew/opt/bison/bin/bison`), then run `sh profiling/run_shadow_nba.sh` and `sh profiling/run_nba_vpi_order.sh`. Both scripts use the local compiler and VVP; the shadow script checks the compile and runtime opt-in gates, the two-intent VPI order, and separate unsafe-shape rejections. This isolated prototype is intentionally not integrated into the shared compiler branch.
