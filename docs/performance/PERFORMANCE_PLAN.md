# VVP performance plan

Status: implementation campaign in progress; see section 9.
Revision studied: `5c7b3319` (2026-10-14). Measurements: [evidence/perf-research-20261014](../../evidence/perf-research-20261014/README.md).
Related earlier work, which this plan extends and does not replace:
- [sim-hotspots survey](../../benchmarks/sim-hotspots/README.md): functor word ops, call-frame slab, dispatch memo, Z3 sampler work.
- [OpenTitan hot-path plan](../conformance/opentitan_hotpath_optimization.md): AA index, Flash backdoor, sparse Z3, VPI lookup.

This document gives an implementing agent:
- where the time goes today;
- what fast simulators do differently;
- an ordered set of work packages (WPs), each with scope, semantic risks, oracles, and promotion gates.

Any speedup is subject to the repository's correctness policy in
[AGENTS.md](../../AGENTS.md). A faster wrong simulator is a regression.

---

## 1. Executive summary

1. **The gap is large and mostly architectural.**
   - On RTL kernels, Verilator 5.020 produces identical output 230-350x faster.
   - Published data puts a 4-state compiled event-driven simulator (CVC) at 35-45x faster than Icarus 10.0, and 111x on SHA1 with a 2-state option.
   - Commercial simulators are compiled-code simulators. VVP is an interpreter of a functor netlist plus a call-threaded bytecode, so it pays per-value-change and per-instruction overheads that compiled simulators do not.
2. **There is substantial low-risk headroom before any architecture change.** The following were all measured on HEAD:
   - PGO alone gave 1.06-1.57x with byte-identical output.
   - A bit-by-bit `%cast2` loop is 12.9% of a behavioral benchmark.
   - `getenv` runs on a hot path.
   - Event-source transaction bookkeeping is about 10-13% of RTL runs.
   - `dynamic_cast` with typeinfo `strcmp` is 5-7% of class-heavy runs.
3. **UVM and testbench time is dominated by call machinery, not by RTL evaluation.**
   - On the UVM benchmark, roughly 40% of the profile is thread creation, automatic-context allocation, context resolution, object-alias registration, and `malloc`/`free` around task and function calls.
   - Commercial simulators run non-blocking functions as native calls with stack frames. Bringing VVP function calls closer to that is the largest single UVM win (WP5).
4. **Constraint-heavy tests are dominated by Z3 (79% of samples).**
   - `Z3_mk_context` alone is 12.7%.
   - Caching per-class constraint analysis and solved domains, plus an exact native fast path for simple constraint shapes, avoids most solver calls (WP7). This must not change distribution semantics or, without a decision, seeded values.
5. **The long-term route to commercial-class RTL speed is a compiled tier.** That means:
   - fused combinational cones;
   - fused same-clock processes;
   - 2-state inference where X/Z is provably impossible;
   - finally, native code for hot processes with interpreter fallback (WP10-WP14).
   CVC's history is the key lesson: VM-level interpreter tuning "increased performance by only a small amount". The large gains came from compiling change propagation and processes to native code.

Do the work in this order: measurement, quick wins, build and toolchain, call
frames and object bookkeeping, randomization, compiler-side netlist and process
fusion, then a native-code tier. Each tier is independently shippable and
independently valuable.

---

## 2. Where the time goes (measured)

All numbers come from the [evidence record](../../evidence/perf-research-20261014/README.md),
on Linux x86-64 with `-O2`, using perf self-time unless marked inclusive.

| Workload | Time | Dominant costs |
| --- | ---: | --- |
| `rtl_pipe` | 1.20 s | `send_vec4` 12.8%, `filter_vec4` 5.1%, event-source transaction family about 13%, `schedule_simulate` 4.7%, `%load/vec4` 3.3%, `schedule_event_` 2.9%, `vthread_run_unpin_` 2.3% |
| `rtl_alu` | 2.73 s | `send_vec4` 15.3%, `filter_vec4` 7.1%, `%load/vec4` 5.1%, `eeq` 3.2%, muxz/cmp functors about 5%, `malloc`/`free` about 2.7% |
| `behav` | 3.97 s | **`of_CAST2` 12.9%** (bit loop), automatic-context lookup about 14%, **`getenv` 2.4%**, `ctx_stats_bump` 1.2%, darray `get_word` 4.3% |
| `classq` | 4.34 s | `pointer_is_live` 4.5%, `strcmp` 4.4% (inside `dynamic_cast`), `malloc`/`free` about 7%, handle copy/reset about 5.5% |
| `uvm_traffic` | 10.81 s | Inclusive: `do_fork_` 12.6%, `of_ALLOC` 10.1%, `do_join` 8.1%, `vthread_delete` 8.1%, `vthread_alloc_context` 7.3%, `vthread_new_` 6.5%, alias register/unregister/notify about 8%, `compile_design` (load) 7.5%, `dynamic_cast` 5% |
| `randomize_dv_txn` | 21.04 s | `libz3` 79%. Inclusive: `Z3_solver_check` 26.7%, `Z3_model_eval` 18.0%, `Z3_mk_context` 12.7%. Interval sampler 28.7%, count-exceeds probe 23.4% |

What the VVP IR costs per Verilog operation. `rtl_pipe` has this source:

```verilog
wire [31:0] mixed = (din ^ (din << 5)) + K;
```

It becomes four functor nodes, connected by full `vvp_vector4_t` message
sends with a filter on each named net:

- a `.part`;
- a `.concat` with a constant;
- a `.functor XOR 32`;
- an `.arith/sum`.

Each `always @(posedge clk)` is a separate thread, woken through an event
functor. Its body is stack bytecode (`%load/vec4`, `%flag_set/vec4`,
`%jmp/0xz`, `%shiftr`, `%xor`, `%assign/vec4`), and each NBA allocates a
scheduled event. A compiled simulator turns the whole stage into about 5
machine instructions per bit-plane inside one clock-domain function.

---

## 3. What fast simulators do (research summary)

| Technique | Who uses it | Relevance to VVP |
| --- | --- | --- |
| **Compile processes and change propagation to native code.** Interpreted fallback through wrappers during bring-up. | CVC ([arXiv 1603.08059](https://arxiv.org/abs/1603.08059), sections 5, 9.5-9.7, and 10.7), VCS, Xcelium, Questa | CVC: an Ertl-style generated VM gave only a small gain. A native flow-graph code generator gave 35-45x over Icarus. This is the strongest precedent for WP14. |
| **Fuse always blocks** triggered by the same event | CVC section 10.4 ("huge speed improvement"), Verilator (whole-design `eval`) | WP12 |
| **Two-state code where X/Z is impossible.** The B-plane code is not emitted. | CVC section 10.6; Verilator (2-state only); Cadence emulation measures 4-state at about 2.3x the cost of 2-state ([DVCon](https://dvcon-proceedings.org/wp-content/uploads/Emulation-Moves-Into-4-State-Logic-and-Real-Number-Modeling-.pdf)) | WP13. Must be proven, never assumed. |
| **Per-instance data plus shared code**, not module inlining | CVC section 10.1 | The VVP design already shares code. Keep this property in any native tier. |
| **Static scheduling and levelization of combinational logic** | Verilator `V3Order`/`V3Sched` ([internals](https://github.com/verilator/verilator/blob/master/docs/internals.rst)), Arcilator ([LLVM Dev 2023](https://llvm.org/devmtg/2023-10/slides/techtalks/Erhart-Arcilator-FastAndCycleAccurateHardwareSimulationInCIRCT.pdf)) | Only partially applicable. IEEE event semantics, `#` delays, VPI, and force/release keep VVP event-driven. Apply levelization inside fused, side-effect-free cones (WP11). |
| **DFG peephole optimization of combinational equations** | Verilator `V3Dfg` | Applies to WP11 cone fusion. |
| **Activity-aware evaluation**: skip partitions whose inputs did not change | ESSENT ([DAC 2020, eScholarship](https://escholarship.org/uc/item/64x147r1); [MIT talk](https://www.csail.mit.edu/node/8376)), GSIM supernodes ([arXiv 2508.02236](https://arxiv.org/abs/2508.02236)) | Event-driven VVP is activity-driven by construction. The lesson is granularity: activity checks per supernode or cone, not per functor. That is cone fusion again. |
| **Parallel partitioned simulation** | RepCut ([ASPLOS 2023](https://escholarship.org/content/qt1345b80b/qt1345b80b.pdf), 27x on 24 threads), Parendi ([arXiv 2403.04714](https://arxiv.org/abs/2403.04714)), Verilator `--threads` | Designed for cycle-based 2-state RTL. Deferred (WP15). Determinism under IEEE 4.7 and UVM seeds makes it high-risk for VVP. |
| **Coroutines for dynamic scheduling** | Verilator timing/UVM support ([CHIPS Alliance](https://www.chipsalliance.org/news/towards-uvm-using-coroutines/)) | A model for how compiled processes suspend and resume in WP14. VVP threads already save their `pc`, which is equivalent. |
| **Superinstructions, replication, threaded dispatch** | Ertl & Gregg, Casey et al. (up to 4.55x on dispatch-bound VMs) ([paper](https://www.eecg.utoronto.ca/~steffan/carg/readings/optimizing-indirect-branch-prediction.pdf)) | VVP opcodes are heavy, so dispatch is not the top cost. Superinstructions help mainly by removing intermediate `vvp_vector4_t` stack traffic (WP4). |
| **Copy-and-patch JIT** from compiler-generated stencils | [Xu & Kjolstad, OOPSLA 2021](https://arxiv.org/abs/2011.13127); CPython 3.13 experimental JIT | A candidate backend for WP14 that avoids an LLVM runtime dependency. Needs per-architecture stencils (macOS ARM64 and x86-64). |
| **LLVM-based JIT/AOT for HDL** | LLHD ([arXiv 2004.03494](https://arxiv.org/abs/2004.03494); a JIT up to 2.4x faster than commercial in cases), nvc (VHDL), GHDL LLVM backend | Heavyweight dependency. Consider only if the AOT C++ route (WP14) stalls. |
| **PGO, LTO, and post-link layout** | BOLT ([arXiv 1807.06735](https://arxiv.org/abs/1807.06735): up to 20% on top of FDO+LTO for large binaries) | WP2. Measured 1.06-1.57x from PGO alone. |
| **Allocators** | mimalloc and jemalloc ([bench](https://microsoft.github.io/mimalloc/bench.html); vendor data, verify locally) | WP2 experiment. `malloc`/`free` is 7-13% in class and UVM runs. |
| **Priority-queue structure** | Calendar queues ([Brown 1988](https://en.wikipedia.org/wiki/Calendar_queue)); hashed/hierarchical timing wheels (Varghese & Lauck, SOSP 1987) | VVP uses a sorted linked list of time slots with O(n) insertion. Measure walk length first (WP9). |
| **Constraint solving**: word-level solvers and BDD/SAT hybrids, plus caching per class | Commercial solvers (patent literature); CRAVE/PyVSC use SMT ([PyVSC paper](https://raw.github.com/fvutils/pyvsc/master/doc/papers/PyVSC_Randomization_Constraints_Coverage_in_Python_final.pdf)) | WP7. Exact uniformity is required, so approximate samplers ([arXiv 1210.4861](https://arxiv.org/abs/1210.4861)) are not acceptable substitutes. |
| **UVM-level costs**: config_db wildcard scopes, factory, reporting | [Siemens config_db guidelines](https://blogs.sw.siemens.com/verificationhorizons/2020/05/07/uvm-configuration-db-guidelines/), [DVCon UVM performance](https://dvcon-proceedings.org/wp-content/uploads/unconstrained-uvm-systemverilog-performance.pdf) | These are testbench-side issues. The simulator's part is making strings, assoc arrays, and queues fast (WP6). Do not patch UVM sources. |

---

## 4. Non-negotiable semantic invariants

Every WP preserves all of these. Each must be stated explicitly in that WP's PR.

1. **Four-state values, widths, and signedness.** X/Z propagation, strengths
   (`vvp_vector8_t`), and resolution must match bit for bit. A 2-state fast
   path is legal only where X/Z is proven impossible, or where a cheap dynamic
   check falls back to the 4-state path (the B-plane is all zero).
2. **Scheduling regions and order.** Preserve the stratified event regions,
   NBA ordering, `#0` inactive, the observed and reactive regions, and the
   wait-order wake rule already pinned by `sv_waiter_set_wake_order.v`. The
   repository cites IEEE 1800-2017/2023 4.4, 4.6, and 4.7. Where IEEE allows
   nondeterminism, the existing VVP order is still the compatibility baseline:
   ivtest gold files encode it. If a change alters any gold output, stop and
   ask the user. Never re-baseline gold files to make a performance change pass.
3. **Observability.** A named net or variable must stay readable, writable,
   and forceable at its current granularity through VPI:
   `vpi_handle_by_name`, `vpi_put_value` with force/release, `$dumpvars`,
   `$monitor`, and UVM HDL backdoor (`uvm_hdl_read/deposit/force`). Any
   fusion or elision may only absorb compiler temporaries (`_ivl_*`) or values
   that are provably unobservable. VPI can name almost anything at run time,
   so "unobservable" usually means "unnamed".
4. **Random stability.** `randomize()`, `$urandom`, and process/object
   seeding must produce the same values for the same seed. Before merge, the
   user must explicitly approve any change to seeded values, such as a
   different number of RNG draws or a different order.
5. **Distribution semantics.** Uniformity over legal solutions, `dist`
   weights (`:=` versus `:/`), `solve...before`, soft priority, and randc
   cycles must hold. Satisfiability alone is not correctness. Use the existing
   uniformity tests.
6. **Real arithmetic.** IEEE 754 doubles. Never use `-ffast-math`, `-Ofast`,
   or `-ffp-contract=fast` in any build profile.
7. **Lifetimes.** Automatic variable lifetime, `fork...join_none` capture,
   class object lifetime and liveness, and handle generations. Liveness
   checks must not become unsafe in exchange for speed.
8. **Diagnostics.** Warnings, errors, `$fatal`, and assertion messages must
   be unchanged in text and count.
9. **Bounded work.** No unbounded loops or retries (AGENTS.md delivery rules).
   Caches have explicit size limits and invalidation.

---

## 5. Measurement protocol (applies to every WP)

- **Correctness first.** Before timing, check correctness:
  - The candidate's full output must be byte-identical to the reference runtime on every benchmark (`benchmarks/sim-hotspots/run.sh <ref-vvp> <new-vvp>`).
  - Run the ivtest legacy and JSON runners, the UVM regression, the negative suite, and the VPI suite, as listed in AGENTS.md.
  - Add exhaustive 4-state equivalence tests for any changed vector operator. The existing pattern is `ivtest/ivltests/vvp_vec4_functor_logic.v` and `vvp_vec4_functor_arith.v`, with gold output generated by the reference runtime.
- **Timing.** Same host and same compiled `.vvp` file. Report the median of 5 runs and the spread. If baseline spread exceeds 5%, fix the measurement first.
  - Report `perf stat -e instructions,task-clock` alongside wall time. Instruction counts are much more stable than wall time on shared or CI hosts.
  - Report max RSS (`/usr/bin/time -f %M`).
- **Promotion gate.**
  - Screening: at least 10% improvement on the targeted benchmark, no more than 2% regression on any other benchmark.
  - Merge evidence: the semantic oracle passes on Linux CI and macOS.
  - End-to-end: for OpenTitan-motivated work, use the same-image Flash, SPI-host, and I2C replays defined in the hot-path plan. Microbenchmark wins alone do not count there.
- **Record** every attempted candidate, including rejected ones, in an attempt ledger. Follow the format of the sim-hotspots README.

---

## 6. Work packages

Effort: S is 1-3 days, M is 1-2 weeks, L is 3-6 weeks, XL is more than 6 weeks.
"Expected" figures are hypotheses to test, not promises.

### Tier A: measurement and low-risk runtime fixes

#### WP0. Benchmark corpus and performance counters (S; prerequisite)

- Extend `benchmarks/sim-hotspots` with these workloads:
  - wide vectors (128-1024 bits);
  - gate-level and UDP primitives with strengths;
  - multi-clock with `#` delays (scheduler pressure);
  - large memories and `$readmemh`;
  - `$display`/`$fwrite` heavy;
  - VCD/FST dump enabled;
  - VPI-callback heavy (`cbValueChange`);
  - strings, assoc arrays, and queues (UVM-like);
  - UVM with heavy `config_db`, factory, and reporting;
  - a forked-process-heavy testbench.
- Keep each one under 10 s on the baseline. Keep `rtl_pipe_x10` and similar scaled variants for Verilator gap tracking.
- Add a `run.sh` mode that emits JSON with these fields: wall time, `perf stat` instructions where available, max RSS, and output hash.
- Add an opt-in runtime statistics dump, enabled at **compile time** (`--enable-perf-stats`, off by default) so it costs nothing in default builds. It counts:
  - events per region;
  - thread creations and wakes;
  - `%callf` and `%fork`;
  - context allocations;
  - functor `recv_vec4` calls by functor kind;
  - an opcode histogram, plus an opcode-pair histogram for WP4;
  - scheduler time-list walk length (WP9);
  - Z3 contexts, checks, and model evaluations.
- Gate: none on speed. Output must be byte-identical with stats disabled.

#### WP1. Remove the "debug tax" from hot paths (S)

Evidence: `getenv` is 2.4% of `behav` and 1% of `classq`, and `ctx_stats_bump` is 1.2%.

- `vthread.cc` has 51 `getenv` sites. Several are evaluated per event, not cached. Examples:
  - `vthread_run` calls `getenv("IVL_FUNC_TRACE")` on every pause of a function thread.
  - `scope_trace_enabled_` calls `getenv` on each call.
  - There are uncached calls in the `IVL_PROC_TRACE`, `IVL_ASSOC_TYPE_TRACE`, `IVL_QUEUE_APPEND_TRACE`, and `IVL_MBX_TRACE` paths.
- Read all `IVL_*` variables once at startup into a `vvp_trace_config` struct. Hot sites test one global `bool any_trace_enabled` before anything else.
- Keep every trace feature working. Developers and agents rely on these traces for diagnosis.
- Also audit `ctx_stats_*`, `warned_*`, and similar per-call bookkeeping. Put them behind the same predicted-false flag.
- Oracle: trace output is identical when each variable is set. Add one smoke test per trace family where none exists.
- Expected: 2-4% on behavioral and class workloads.

#### WP2. Build-profile performance: PGO, LTO, allocator (S-M)

Evidence: PGO measured 1.06-1.57x with byte-identical output (in-sample).

- Add `configure --enable-pgo` with a scripted two-stage build. Train on a dedicated training set that is disjoint from the evaluation set: ivtest subsets plus UVM smoke tests.
- Also evaluate:
  - LTO (`-flto`) for `vvp` and `ivl`;
  - `-fno-plt`;
  - BOLT on Linux;
  - macOS ARM64 with Apple clang PGO (`-fprofile-instr-generate/use`).
- Allocator: benchmark `LD_PRELOAD` mimalloc and jemalloc first. Adopt one only if it wins on both Linux and macOS, and keep it optional.
- Allocation changes reorder pointers. The sim-hotspots work already removed pointer-order dependence from waiter sets. Check for any remaining pointer-keyed iteration (`std::set<T*>`, `std::map<T*,...>`) that affects output order: grep, then audit.
- Never enable `-ffast-math`.
- Oracle: full gate suite on the PGO build. Run CI with and without PGO so a non-PGO build stays green.
- Expected: 1.05-1.5x across the board. RTL-heavy workloads gain most.

#### WP3. Word-wide 4-state operations everywhere (M)

Evidence: `of_CAST2` alone is 12.9% of `behav`.

- `of_CAST2` sets X/Z to 0 one bit at a time. The VVP planes encode 0=(a0,b0), 1=(a1,b0), Z=(a0,b1), X=(a1,b1); see `WORD_*_ABITS`/`WORD_*_BBITS` in `vvp/vvp_net.h`. Over words, that operation is `a &= ~b; b = 0`.
- Audit every per-bit loop: `.value(idx)` and `set_bit(idx` sites. The counts are:
  - `vthread.cc`: 44
  - `vvp_net_sig.cc`: 38
  - `arith.cc`: 29
  - `delay.cc`: 22
  - `vvp_net.cc`: 20
  - `logic.cc`: 13
- Convert the hot loops to word operations on the A and B planes, keeping the bit loop for strength (`vector8`) and for mixed-width cases.
- Add a cheap "is 2-state?" check: when the B-plane is all zero, arithmetic and compares can take a direct `uint64_t` path for widths of 64 bits or less.
- Oracle: exhaustive 4-state equivalence regressions for each converted operator at widths 1/2/8/31/32/33/63/64/65/128, with signed and unsigned operands, shift-amount X/Z, and over-shift. Gold output comes from the reference runtime.
- Expected: 10-15% on `behav`, 5-10% on RTL kernels.

#### WP4. Interpreter fast paths (M)

- **Event-source transactions** (about 10-13% of RTL runs):
  - `vvp_event_callback_begin`/`end` move-construct and save an `event_source_transaction_s`, and push to `event_source_saved_` on every callback.
  - Add an empty-transaction fast path that skips the moves and the vector push when nothing is pending. Represent "nothing pending" with a depth counter.
  - Oracle: the event-callback ordering regressions plus the scheduler audit tests.
- **Stack traffic:**
  - `pop_vec4` returns by value and `push_vec4` copies.
  - Use move semantics (the build already uses C++11), in-place `peek` for unary ops, and binary ops that write into the left operand's stack slot.
- **Superinstructions:** derive them from the WP0 opcode-pair histogram only. Likely candidates from the IR:
  - `%load/vec4` followed by `%flag_set/vec4 N` and `%jmp/0xz`;
  - `%load/vec4 a; %load/vec4 b; <binop>`;
  - `%pushi/vec4` followed by `%assign/vec4`.
  - Each needs synchronized changes to `vvp/codes.h`, `vvp/compile.cc`, `vvp/lexor.lex`/`parse.y`, `tgt-vvp` emission, and malformed-bytecode validation (AGENTS.md).
- **Width-specialized opcodes:** add variants for operands of 64 bits or less that keep values in thread word registers rather than `vvp_vector4_t`. The compiler emits them only when widths are statically known.
- **Dispatch loop:** it checks `trampoline_switch_to` on every instruction. Fold that into the return protocol: for example, `%callf` returns false with a reason code.
- **`vthread_s` layout:**
  - The frame is about 3.5 KB and zero-filled per call.
  - `flags[512]` holds one `vvp_bit4_t` per byte. Bit-pack it or zero it lazily.
  - Replace the small `std::vector` members with inline small arrays.
- Expected: 1.2-1.6x on RTL kernels when combined with WP3.

### Tier B: testbench, UVM, and randomization

#### WP5. Lightweight synchronous call frames (L; largest UVM win)

Evidence: about 40% of the `uvm_traffic` profile is call machinery:
- `do_fork_` and `vthread_new_`;
- `vthread_alloc_context`/`of_ALLOC`, `of_FREE`, and `do_join`;
- `copy_method_ports_to_context_`;
- context resolution (`resolve_context_scope`, `vthread_get_rd_context_item_scoped`, `find_stacked_context_match_`);
- the `vvp_object` alias register/unregister done during `reset_instance` and free;
- `malloc`/`free`.

Required reading: [m6_callf_rearchitecture.md](../conformance/m6_callf_rearchitecture.md),
[auto_var_storage_refactor_notes.md](../conformance/auto_var_storage_refactor_notes.md),
and the trampoline implementation (`IVL_TRAMPOLINE_CALLF` path in `vvp/vthread.cc`).

- **Goal:** a SystemVerilog `function` cannot consume time. For such functions, and for tasks proven not to block, run the callee without allocating a `vthread_s` or a heap context:
  - Use a contiguous per-thread frame arena with bump allocation and LIFO release.
  - Give automatic variables frame slots instead of per-variable `_aa` functor storage plus a context-record lookup.
  - Pass arguments directly in the frame.
- **Compiler side:** `tgt-vvp` or elaboration tags call sites and callees with a "never blocks, never captures" property. The property is false if the function:
  - forks;
  - contains `wait`, `@`, or `#` (tasks);
  - calls something that can block;
  - takes `ref` arguments to automatics that outlive the call;
  - is a target of DPI export callbacks that suspend;
  - creates `fork...join_none` closures over its automatics;
  - has automatics that are VPI-visible while live.

  Treat anything unproven as the existing slow path.
- **Escape handling:** if a frame is captured, promote it to a heap context before the capture. Captures include a closure, a `ref` held by a forked child, a VPI handle obtained by name, and `$dumpvars` of automatics. This is the hardest part, so design it first and write the design doc before writing code.
- **Virtual dispatch:** keep the existing memoized `(class, method) -> (pc, scope)` map. Add an inline cache at the call site, keyed by the receiver's class.
- Oracle:
  - all automatic-lifetime, recursion, `fork...join_none` capture, `process` API (`self`, `kill`, `suspend`), `disable`, and DPI export/import regressions;
  - the UVM regression with real DPI;
  - new tests for recursion depth, re-entrancy through VPI callbacks, and `disable` of a function's parent scope during a call.
- Expected: 1.5-2.5x on UVM-traffic-style workloads. This is a hypothesis; WP0 counters must confirm the call-count share first.

#### WP6. Object, alias, and waiter bookkeeping (M)

- **Alias registration** on every alloc and free:
  - Today `vvp_fun_signal_object_aa::reset_instance` registers and unregisters signal aliases even when nobody waits on the object.
  - Make aliasing lazy: register only when a `wait`/`@` on a class property, or a VPI value-change callback, subscribes. Use a generation counter so stale entries can be skipped instead of eagerly erased.
- **Waiter sets:**
  - Replace `std::set<vthread_s*>` and `std::map<object_mutation_key_t, std::set<...>>` with intrusive, wait-ordered lists. Order must be preserved; it is pinned by `sv_waiter_set_wake_order.v`.
- **`dynamic_cast` on hot paths** (5-7% including the typeinfo `strcmp`):
  - There are 581 `dynamic_cast` sites in `vvp/*.cc`. Profile-rank them.
  - Replace the hot ones with a `kind()` tag or virtual accessors.
  - Check whether `-rdynamic` or non-merged typeinfo is what forces the `strcmp` path. If a link-flag fix removes it, prefer that.
- **Handle copies:** `vvp_object_t` copy and reset with the liveness check (`pointer_is_live`) on every copy. Consider generation-tagged handles so liveness is a single compare, while keeping exact semantics for freed and reused pointers.
- **Containers and strings:**
  - Small-string optimization is already in `std::string`. Check queue (`std::deque`) and assoc-array allocation patterns.
  - `_Deque_base::_M_initialize_map` shows up at about 2%: every `vvp_process` or queue constructs a deque map eagerly.
- Oracle: object lifetime, handle generation, alias wait, `wait(obj.prop)`, VPI value-change, and queue/assoc regressions; OpenTitan class-heavy rows.
- Expected: 10-25% on `classq` and `uvm_traffic`.

#### WP7. Randomization: cache analysis, avoid Z3 where exactly possible (M-L)

Evidence: `randomize_dv_txn` spends 79% in Z3:
- `Z3_mk_context` 12.7%;
- interval sampling 28.7%;
- `z3_isolated_count_exceeds_` 23.4%;
- `Z3_model_eval` 18%.

Read the sim-hotspots Z3 section and attempt ledger first: context reuse was rejected for random-stability reasons.

1. **Per-class constraint analysis cache.** Cache the result of factoring, isolation proofs, variable support sets, and the AST template. Key it by `(class_type, constraint_mode bitmap, rand_mode bitmap, inline-constraint call site)`.
   - Each call then only instantiates state-variable values.
   - Every call still uses a fresh Z3 context and the same RNG consumption.
2. **Solved-domain cache.** Some isolated factors depend only on constants and the variable itself, not on state variables or other random variables. For those, the legal interval list is identical every call. Cache it and sample from it without Z3.
   - Random stability: the sampler must draw from the RNG stream in exactly the same sequence as the uncached path. If that is impossible, it is a seeded-value change and needs the user's decision.
3. **Native exact fast path** for common shapes, using interval and mask arithmetic only:
   - `inside` sets and ranges;
   - `dist` over constants;
   - alignment masks (`addr[1:0]==0`);
   - small-enum implications.

   Exhaustive equivalence against the Z3 path on small domains is mandatory: the same legal set and the same distribution. When a value change is accepted, the same seeded values are also required.
4. **Z3 context cost.** Context creation is about 2.7 ms.
   - Measure `Z3_mk_context_rc` with a minimal parameter set that does not change solver configuration (`auto_config` was rejected).
   - Upgrading from Z3 4.8.12 may help, but models may differ. That is acceptable only on paths whose picks are model-order-independent (the sim-hotspots "model-order independence" item).
- Oracle: the `sv_rand_conformance_*`, `sv_randomize_*uniform*`, randc, `solve...before`, soft-constraint, and `dist` suites under 2017 and 2023, plus seeded-value identity checks.
- Expected: 2-5x on constraint-heavy rows (SPI host, I2C, RV-DM in the OpenTitan census). Measure on census replays.

#### WP8. Load and compile time (M-L)

- Parsing the text `.vvp` takes 7.5% of a short UVM run. Compiling UVM takes 4.2 s and 266 MB per testbench.
- Short term:
  - make the VVP lexer and parser cheaper (flex `-Cf` is already applied);
  - intern symbols;
  - avoid `std::string` temporaries in `compile.cc`.
- Medium term:
  - a binary `.vvp` cache, keyed by the input file hash and the runtime version, written next to the text file;
  - or separate compilation of packages, so the UVM package elaborates and emits once and is linked with each test. This is closer to commercial `-partcomp` and snapshots. It needs a design doc covering parameterized classes, `typedef` specialization, and DPI linkage.
- Oracle: identical simulation output from cached and uncached loads; cache invalidation tests.

#### WP9. Scheduler time queue (S to measure, M to change)

- `schedule_event_` walks a delta-linked list of `event_time_s` to insert, so insertion is O(distinct future times).
- Measure the walk length with WP0 counters on UVM and OpenTitan rows that have many timeouts and multiple clocks.
- Change it only if walks are long. Option: a two-level structure, with a timing wheel for the near future and a heap for the far future, keeping per-slot region lists FIFO.
- Also check whether `generic_event_s`/`vthread_event_s` allocations are slab-backed. `vthread_event_s` and `assign*_event_s` already are.
- Oracle: scheduler conformance inventory tests, the `#0`/NBA/observed/reactive ordering suites, and `$time` reporting.

### Tier C: compiler-side netlist and process optimization

#### WP10. Combinational netlist cleanup in `ivl` (M)

- `cprop` and `nodangle` are the only default functors (`tgt-vvp/vvp.conf.in`). Look for cases where the netlist creates avoidable nodes:
  - BUFZ for port connections;
  - `.part` plus `.concat` with a constant for shifts by a constant;
  - `.concat` of all constants.
- Emit direct functors, such as a constant-shift functor, instead of part/concat chains.
- Oracle: exact output across ivtest. Count `.functor`, `.part`, and `.concat` lines in generated `.vvp` files before and after.

#### WP11. Fused combinational cones (L)

- Collapse maximal trees of pure combinational functors whose internal nets are compiler temporaries into one `.cone` functor. Example: `rtl_pipe`'s `.part -> .concat -> XOR -> .arith/sum` becomes one functor driving the named net `mixed`.
- The cone holds a small register-based micro-program over `vvp_vector4_t`, with 64-bit-or-less 2-state fast paths. It evaluates once per input change and sends once.
- Named nets stay nodes, with filters, force/release, and VPI intact (invariant 3).
- Zero-delay glitch counts may change when several inputs change in the same time step. IEEE treats ordering here as nondeterministic, but ivtest gold files must not change; if any does, stop and ask.
- This is the VVP version of Verilator DFG, GSIM supernodes, and CVC flow-graph propagation. It is also the unit a later native tier compiles (WP14).
- Requires synchronized changes: `tgt-vvp` emission, `vvp/compile.cc` and parser, a new functor class, and malformed-bytecode validation.
- Expected: 1.5-3x on continuous-assign-heavy RTL, because `send_vec4` plus `filter_vec4` is 18-22% today and the per-hop cost multiplies with cone depth.

#### WP12. Process fusion and NBA batching (L)

- Fuse `always` processes that have an identical sensitivity (`@(posedge clk)`), have no blocking assignments to shared variables, and whose bodies are NBA-only plus pure reads. Fused processes form one thread that runs the bodies in the existing VVP order.
- For NBA-only clocked processes, batch NBAs into a per-domain update list instead of one scheduled event per assignment.
- Preserve the NBA update order exactly. IEEE 1800 requires NBAs from one process to update in execution order. Writing a variable from more than one process must disable fusion.
- Check `$display` and other system-task side effects in bodies. Any side effect other than an NBA disables fusion unless the order is provably preserved.
- CVC reports this as a "huge speed improvement" (section 10.4).
- Oracle: ivtest exact output; dedicated tests for:
  - multiple NBAs to the same variable;
  - NBAs with intra-assignment delays (no fusion);
  - `disable` of a fused process's named block (no fusion when a process is named or targetable);
  - VPI `vpiProcess` iteration, if exposed.

#### WP13. Proven 2-state code generation (M-L)

- For variables of 2-state type (`bit`, `int`, `byte`, `longint`, and 2-state structs/arrays), expressions over them are 2-state when every operand is 2-state and no operator can introduce X. Division by zero yields X in 4-state contexts, so check what the LRM says for 2-state results; X also appears on out-of-range reads.
- Emit 2-state opcodes or cone instructions that skip B-plane work.
- Eliminate `%cast2` when the operand is already 2-state. `behav.vvp` emits `%cast2` for compound l-value reads of `int`s.
- Never infer 2-state for 4-state-typed nets from "they are never X in practice". Only the type and the operators prove it.
- Oracle: exhaustive tests mixing 2- and 4-state operands, X-producing operators (`/`, `%`, out-of-range selects, X shift amounts), and casts.

### Tier D: native code and parallelism

#### WP14. Native-code tier for hot processes and cones (XL; research spike first)

- **Spike (M) first: speed-of-light prototype.**
  - Hand-write the C++ a generator would produce for the `rtl_pipe` `stage`:
    - per-instance state struct;
    - a combinational cone function;
    - a clock-domain function using the runtime's `vvp_vector4_t` APIs for 4-state;
    - a scheduler hook that the interpreter calls instead of the thread.
  - Load it as a VPI-style shared object.
  - Measure the speedup over the interpreter. This bounds the payoff before any generator is built.
- **Recommended architecture:** AOT C++ emission from `tgt-vvp` (or a new `tgt-vvpcc`), compiled by the system compiler and loaded by `vvp` alongside the `.vvp` file, with per-process interpreter fallback.
  - CVC used a wrapper approach (`I_CALL_ASLPROC`/`ASLFUNC`) so that any construct not yet compiled ran in the interpreter. Start with cones and NBA-only clocked processes, then expand.
  - This route is debuggable, needs no runtime LLVM dependency, and works on macOS ARM64 and Linux.
- **Alternatives:**
  - A copy-and-patch JIT built from stencils of the existing opcode implementations: no system compiler needed at run time, but per-architecture work.
  - LLVM ORC: large dependency.

  Choose one only after the spike.
- **Suspend and resume:** compiled processes that hit `@`, `#`, or `wait` return a resume label, like a switch-based coroutine. They keep all region semantics in the existing runtime scheduler.
- **Guardrails:**
  - every compiled construct has an equivalence test against the interpreter;
  - a runtime flag (`-no-native`) forces pure interpretation for differential testing;
  - CI runs both modes.
- Expected: per CVC and Verilator evidence, 10-50x on RTL-heavy simulations, with smaller gains on UVM-heavy runs, where WP5-WP7 matter more.

#### WP15. Parallelism (deferred)

Partitioned parallel RTL simulation (RepCut, Parendi, Verilator mtasks)
assumes cycle-based static scheduling. With VPI, UVM, and IEEE nondeterminism
being resolved deterministically, it is high risk.

Lower-risk options, in this order:
1. Off-thread waveform encoding. CVC reports up to 2x for dump-heavy runs.
2. Parallel regression execution. It already exists through `scripts/ivtest-parallel.sh` and census runners.
3. Only after WP14: parallel evaluation of independent fused cones within one time slot, with deterministic merge.

---

## 7. Recommended sequence and expected cumulative effect

| Step | WPs | Effort | Cumulative expectation (hypothesis) |
| --- | --- | --- | --- |
| 1 | WP0, WP1, WP2 | about 2 weeks | 1.2-1.6x broadly. Measurement infrastructure in place. |
| 2 | WP3, WP4 | about 3 weeks | RTL 1.5-2.5x versus today. Behavioral 1.3-1.6x. |
| 3 | WP6, WP5 | about 6-8 weeks | UVM and class 2-3x versus today. |
| 4 | WP7, WP9, WP8 | about 4-6 weeks | Constraint-heavy rows 2-5x. Faster UVM startup. |
| 5 | WP10, WP11, WP13, WP12 | about 8-12 weeks | RTL 3-8x versus today. |
| 6 | WP14 spike, then incremental | about 3+ months | RTL toward 10-50x. Approaches the commercial class on RTL. |

Steps 1-4 do not change the `.vvp` format except for WP4 superinstructions,
which are optional. Steps 5-6 add new IR constructs. Keep the interpreter as
the reference semantics throughout.

---

## 8. Process rules for the implementing agent

- Each WP is one ticket in `.ai/ACTIVE_WORK.yaml`, with ID `PERF-WPn`, and gets one PR against `main`. Follow the AGENTS.md targeted-fix protocol:
  - **reproducer:** the benchmark plus counters;
  - **expected semantics:** byte-identical output;
  - **root cause:** the profile evidence;
  - scope lock.
- Keep one active WP at a time. Record unrelated discoveries in `docs/conformance/DISCOVERED_DEBT.md`.
- Every PR includes:
  - before/after tables using section 5's protocol;
  - the semantic-invariant checklist from section 4;
  - the attempt ledger.
- Update this plan's WP status table (section 9) and the evidence directory. Never overwrite earlier measurements; append revision-scoped results.
- When a hypothesis fails (no gain), revert the candidate, record it, and move on. Do not keep code that does not pay for itself.
- Stop and ask the user before:
  - any change that alters ivtest gold output or seeded random values;
  - adding a new required dependency (LLVM, mimalloc);
  - starting WP14 beyond the spike.

## 9. Status

| WP | Status | PR | Measured result |
| --- | --- | --- | --- |
| WP0 | MERGED | #584 | Merged as `0490e2ff`; Fast Linux passed. On its recorded base, outputs matched and the Callgrind stats-off comparison changed whole-process instructions by +274, with selected hot-path counts identical. See [WP0 evidence](../../evidence/perf-wp0-a5aad316/README.md). |
| WP1 | REJECTED | - | The `IVL_*` trace/context-stat screen improved `behav` instructions by 3.310901%, below the gate; outputs matched. See [WP1 evidence](../../evidence/perf-wp1-debug-tax-0490e2ff/README.md). |
| WP2 | POST-REBASE GATES PASS; EXACT-HEAD CI TRACKED IN PR | #599 (draft) | On pinned base `c7ebca768c21c251d9c165c9aff0e363768030b1`, Caliptra mcycle 100–200 Callgrind instructions fell 10.259915%; the focused hotloop fell 9.212159%. On the single new base `845f54a5724c4d2af13dde40eca6d290c80c41d9`, the same window fell from 183,325,396,223 to 164,442,681,700 instructions (−10.300108%, Slurm job 1496). The VPI screen intentionally stops at mcycle 200; it is not a full firmware pass. All 18 pinned-base corpus outputs matched, and the largest other instruction increase was +0.038453%. Slurm job 1457 passed pinned-base gates. Slurm job 1497 passed the final new-base build and correctness gates: `make check`, legacy (7,436 total; 7,431 passed, 0 failed, 2 not implemented, 3 expected failures), VPI (131/131), negative (152/152), JSON (4,675/4,675), runtime invariants (15/15), and UVM (367/0/0, real DPI). A4 confirmed the prior 16 JSON failures were fixed by #595. The full three-run wall table is [here](../../evidence/wp2-predecode-c7eb-20261015/wall-corpus-c7eb-20261015-r1/results/wall-summary.csv); the largest candidate spread is 43.445690%, supporting only. Rebased exactly once. Exact-head cross-platform `test.yml` status is tracked in PR #599. See [post-rebase screen and gates](../../evidence/wp2-predecode-rebase-845f54a-20261016/README.md). |
| WP3 | MERGED | #593 | `of_CAST2` improved `behav` instructions by 14.079590%; 18/18 outputs matched and exact-head Linux, macOS, Windows, and Slurm gates passed. See [WP3 evidence](../../evidence/perf-wp3-cast2-c7eb/README.md). |
| WP4-WP15 | NOT STARTED | - | - |

### WP0 pinned-base before/after table

Five interleaved pairs; one CPU; task-clock is primary because the host did not
support the instruction counter. Ratios are reference divided by candidate.
The exact pinned base is `f9f8e0a79f230f38da6cbb4445994ad1075ad531`.

| Benchmark | Reference wall median (s) | Candidate wall median (s) | Reference task-clock (ms) | Candidate task-clock (ms) | Reference spread | Ref/candidate task-clock |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| behav | 4.470 | 4.473 | 4437.89 | 4444.63 | 0.25% | 0.9985x |
| classq | 5.723 | 5.673 | 5679.72 | 5636.79 | 1.45% | 1.0076x |
| fork_heavy | 0.514 | 0.516 | 465.18 | 465.38 | 1.37% | 0.9996x |
| gate_strength | 1.466 | 1.467 | 1452.46 | 1456.05 | 0.54% | 0.9975x |
| io_text | 0.114 | 0.114 | 65.62 | 65.82 | 1.17% | 0.9970x |
| large_memory | 0.114 | 0.114 | 94.41 | 94.79 | 0.58% | 0.9960x |
| multi_clock | 0.315 | 0.316 | 286.24 | 286.79 | 0.56% | 0.9981x |
| randomize_dv_txn | 4.980 | 4.977 | 4923.92 | 4927.52 | 0.81% | 0.9993x |
| randomize_z3 | 1.320 | 1.318 | 1301.32 | 1291.79 | 2.87% | 1.0074x |
| rtl_alu | 3.822 | 3.822 | 3807.65 | 3809.53 | 0.49% | 0.9995x |
| rtl_pipe | 7.178 | 7.177 | 7145.56 | 7141.26 | 2.49% | 1.0006x |
| strings_aa_queue | 3.118 | 3.120 | 3088.20 | 3095.19 | 0.92% | 0.9977x |
| uvm_config_factory | 0.616 | 0.616 | 593.91 | 596.08 | 1.34% | 0.9964x |
| uvm_traffic | 3.523 | 3.523 | 3497.44 | 3495.48 | 2.92% | 1.0006x |
| vpi_callbacks | 5.123 | 5.124 | 5091.08 | 5082.60 | 0.66% | 1.0017x |
| waveform_fst | 0.715 | 0.715 | 660.04 | 659.91 | 0.73% | 1.0002x |
| waveform_vcd | 0.615 | 0.615 | 586.29 | 587.80 | 1.43% | 0.9974x |
| wide_vectors | 0.264 | 0.264 | 232.19 | 231.84 | 0.61% | 1.0015x |

Job 1058 supplied `+ntb_random_seed=73014` to both runtimes and used
`/dev/shm` for temporary outputs. The complete five-pair JSON and CSV are in
the [WP0 evidence directory](../../evidence/perf-wp0-a5aad316/measurements/f9f8e0a/job1058-stable/).

The disabled-build Callgrind A/B on the same pinned base produced byte-identical
output. The selected hot-path instruction counts matched exactly between the
reference and stats-off candidate; the full process totals were 94,558,243,526
and 94,558,243,596 (+70 outside those selected functions). The stats-off
configuration leaves `VVP_PERF_STATS` undefined and the candidate has no
`vvp_perf_stats_*` symbols. Raw profiles and the attempt note are in
[`instruction-ab`](../../evidence/perf-wp0-a5aad316/instruction-ab/README.md).

### Revised A5 speedup campaign

Keep one active PR at a time and pipeline isolated candidate screens while its
gates run. WP1's `IVL_*` trace/context-stat screen was rejected; WP3's
word-wide `of_CAST2` is merged as #593. The `%prop/index/check` predecode
screens retain the campaign pin and include one post-rebase result on `845f54a`.
Continue with each #536
Caliptra hotspot separately: `vpip_vec4_to_int64_saturated`, `of_LOAD_VEC4`,
`copy_from_big_`, allocation, and `__dynamic_cast`. Keep a candidate only if
its target improves by at least 10%, every other corpus instruction count
regresses by no more than 2%, and outputs match. Otherwise revert and record
the result below. Wall time is supporting evidence: record the final PR
medians and all spreads from three runs, and do not block an instruction-count
pass on a wall-time spread above 5%. The Caliptra reference is 7.775 cycles/s.

The source-verified technique ranking and limits are in
[`SOTA.md`](SOTA.md). The WP1 trace/context-stat screen (−3.31% `behav` Ir)
remains rejected. The property/index predecode synthetic hotloop is below the
10% threshold at −9.212159%, while the pinned Caliptra screen clears the gate at
−10.259915% and the one new-base screen on `845f54a` clears it at −10.300108%.
Focused correctness and broad output checks and pinned-base full gates pass;
the final new-base correctness gates passed in Slurm job 1497. Exact-head CI is
tracked on PR #599. The fused
word-plane converter needs one post-#593 remeasurement before its PR, then
`of_LOAD_VEC4`, then measured vec4 stack-slot capacity reuse. A2's c339/main
Caliptra sampling is a separate diagnosis; neither its 500-cycle nor 4,900-cycle
sample reproduced the full-row regression. In Phase
2, inspect the existing virtual-dispatch memo and hot cast sites, then fuse one
pair chosen from the pinned WP0 histogram. Gate activity suppression or
levelization on more than 35% inclusive net-propagation cost; keep the JIT in
Phase 3 as a measured ceiling spike.

| Candidate | Measurement base | Target before → after | Worst other count change | Verdict | PR |
| --- | --- | --- | --- | --- | --- |
| WP1 trace/context stats | `0490e2ff48f3169283e7d71afe2a16424e2cf3aa` | `behav`: 94,570,528,237 → 91,439,391,991 Ir (−3.310901%) | `randomize_z3`: +0.168452% | REJECTED: below 10%; outputs identical | [evidence](../../evidence/perf-wp1-debug-tax-0490e2ff/README.md) |
| WP3 word-wide `of_CAST2` | `c7ebca768c21c251d9c165c9aff0e363768030b1` | `behav`: 94,553,323,869 → 81,240,603,069 Ir (−14.079590%) | 0.000000% | MERGED as `ccaecfe7`; final three-run wall table records all spreads; Slurm job 1292 and exact-head Linux/macOS/Windows CI passed | [evidence](../../evidence/perf-wp3-cast2-c7eb/README.md) |
| A2 Caliptra regression profile | A5 pin `c7ebca768c21c251d9c165c9aff0e363768030b1`; compare c339 vs `3335fe7ec1495956c8adc5788e9a53b0f1756ecf` | Same test; 100–5000 cycle sample was 0.094% faster on main and did not explain the reported row | - | Diagnosis only; neither sampled window reproduces the full-row slowdown | [evidence](../../evidence/a5-a2-top-profile-d1529-20261015/README.md) |
| `%prop/index/check` predecode + packed result | `c7ebca768c21c251d9c165c9aff0e363768030b1`; new-base screen `845f54a5724c4d2af13dde40eca6d290c80c41d9` | Caliptra mcycle 100–200: 184,080,599,400 → 165,194,086,031 Ir (−10.259915%) on the pin; 183,325,396,223 → 164,442,681,700 (−10.300108%) after rebase. Focused hotloop remains −9.212159%. | 18/18 pinned outputs match; largest other count change +0.038453%. New-base inputs/visible prefix match; inverted assertion rejected. | Both instruction screens and final new-base correctness gates pass (Slurm 1497). Exact-head CI status is tracked on PR #599. Focused legacy/JSON 19/19 each and malformed metadata 16/16 passed. Wall medians/spreads are supporting evidence in the [three-run table](../../evidence/wp2-predecode-c7eb-20261015/wall-corpus-c7eb-20261015-r1/results/wall-summary.csv); largest candidate spread 43.445690%. The bounded Caliptra screens stop at mcycle 200, before firmware completion. | [draft #599](https://github.com/dsellerbrock/iverilog-uvm/pull/599); [pinned Caliptra evidence](../../evidence/wp2-predecode-caliptra-c7eb-20261015/attempt-1420/README.md); [post-rebase screen and gates](../../evidence/wp2-predecode-rebase-845f54a-20261016/README.md) |
| `vpip_vec4_to_int64_saturated` word-plane fallback | `c7ebca768c21c251d9c165c9aff0e363768030b1` | Whole focused process: 2,342,072,014 → 1,863,201,596 Ir (−20.446443%) | 18/18 Callgrind counts; worst +0.001880%; outputs 18/18 match; FST paired under `--fair-sched=yes` | SCREEN PASSED on c7eb; repeat once after rebase to `ccaecfe7`; `perf stat` instructions unsupported | [evidence](../../evidence/wp2-converter-c7eb-20261015/wordscan-screen/README.md) |
| `vpip_vec4_to_int64_saturated` fused X/Z scan follow-up | `c7ebca768c21c251d9c165c9aff0e363768030b1` | Whole focused process: 2,342,144,538 → 1,861,170,476 Ir (−20.535627%) | 18/18 outputs match; counts range −0.026238% to +0.002218%; wide/narrow X/Z edge checks pass | SCREEN PASSED on c7eb; repeat once after rebase to `ccaecfe7`; 0.089-point difference is unmatched because input added a narrow-Z assertion | [evidence](../../evidence/wp2-converter-c7eb-20261015/wordscan-screen/fusedxz-broad-20261015/README.md) |
| Allocation reuse for thread vec4 stack | `c7ebca768c21c251d9c165c9aff0e363768030b1` | Callgrind Ir / allocation counts before → after | - | PENDING; separate candidate | - |
| `of_LOAD_VEC4` / `copy_from_big_` | `c7ebca768c21c251d9c165c9aff0e363768030b1` | Callgrind inclusive before → after | - | PENDING; profile after stack screen | - |
| `__dynamic_cast` / type-tag path | `c7ebca768c21c251d9c165c9aff0e363768030b1` | Callgrind by call site before → after | - | PENDING; profile UVM and Caliptra; no padding assumption | - |
| Existing virtual-dispatch memo / optional inline cache | `c7ebca768c21c251d9c165c9aff0e363768030b1` | Callgrind map lookup/miss cost | - | PENDING; only consider a call-site cache if the current memo is hot | - |
| Hot-pair fusion | `c7ebca768c21c251d9c165c9aff0e363768030b1` | WP0 pair count / Callgrind before → after | - | PENDING; one non-suspending pair, not top 15 | - |
| Activity suppression / local levelization | `c7ebca768c21c251d9c165c9aff0e363768030b1` | `recv_vec4` + `send_vec4` + `schedule_*` inclusive share | - | GATED; prototype only above 35% | - |
| Copy-and-patch JIT ceiling spike | `c7ebca768c21c251d9c165c9aff0e363768030b1` | Callgrind Ir, startup cost, code size | - | PENDING; spike only, no productionization | - |

Completion requires WP0 merged, WP3 plus at least two more aggressive-technique
PRs merged, final before/after instruction counts and wall-time medians, a
cumulative `caliptra_top` cycles/s result against 7.775, and a measured JIT
ceiling. Each evidence directory and PR table records its pinned base. Rebase
once immediately before each merge; compare the pinned base with
`origin/main` for runtime/benchmark/build-path changes and remeasure only when
that diff requires it.

## References

- S. Meyer, *CVC Verilog Compiler: Fast Complex Language Compilers Can be Simple*, [arXiv:1603.08059](https://arxiv.org/abs/1603.08059).
- S. Beamer, D. Donofrio, *Efficiently Exploiting Low Activity Factors to Accelerate RTL Simulation* (ESSENT), DAC 2020. [eScholarship](https://escholarship.org/uc/item/64x147r1).
- H. Wang, S. Beamer, *RepCut: Superlinear Parallel RTL Simulation with Replication-Aided Partitioning*, ASPLOS 2023. [PDF](https://escholarship.org/content/qt1345b80b/qt1345b80b.pdf).
- *GSIM: Accelerating RTL Simulation for Large-Scale Designs*, [arXiv:2508.02236](https://arxiv.org/abs/2508.02236).
- *Parendi: Thousand-Way Parallel RTL Simulation*, [arXiv:2403.04714](https://arxiv.org/abs/2403.04714).
- Verilator internals, [docs/internals.rst](https://github.com/verilator/verilator/blob/master/docs/internals.rst); [Verilator Internals (2020)](https://veripool.org/papers/Verilator_Internals1_202010.pdf).
- M. Erhart et al., *Arcilator: Fast and Cycle-Accurate Hardware Simulation in CIRCT*, [LLVM Dev Mtg 2023](https://llvm.org/devmtg/2023-10/slides/techtalks/Erhart-Arcilator-FastAndCycleAccurateHardwareSimulationInCIRCT.pdf).
- F. Schuiki et al., *LLHD: A Multi-level Intermediate Representation for Hardware Description Languages*, [arXiv:2004.03494](https://arxiv.org/abs/2004.03494).
- H. Xu, F. Kjolstad, *Copy-and-Patch Compilation*, OOPSLA 2021, [arXiv:2011.13127](https://arxiv.org/abs/2011.13127).
- K. Casey, M. A. Ertl, D. Gregg, *Optimizing Indirect Branch Prediction Accuracy in Virtual Machine Interpreters*, [PDF](https://www.eecg.utoronto.ca/~steffan/carg/readings/optimizing-indirect-branch-prediction.pdf).
- M. Panchenko et al., *BOLT: A Practical Binary Optimizer for Data Centers and Beyond*, [arXiv:1807.06735](https://arxiv.org/abs/1807.06735).
- R. Brown, *Calendar Queues*, CACM 1988, [summary](https://en.wikipedia.org/wiki/Calendar_queue).
- G. Varghese, T. Lauck, *Hashed and Hierarchical Timing Wheels*, SOSP 1987.
- Antmicro/CHIPS Alliance, [coroutines for dynamic scheduling in Verilator](https://www.chipsalliance.org/news/towards-uvm-using-coroutines/).
- Embecosm, [Icarus versus Verilator case study](https://embecosm.com/appnotes/ean6/html/ch06s05s01.html).
- Siemens, [UVM configuration DB guidelines](https://blogs.sw.siemens.com/verificationhorizons/2020/05/07/uvm-configuration-db-guidelines/).
- Cadence, [Emulation Moves Into 4-State Logic and Real Number Modeling](https://dvcon-proceedings.org/wp-content/uploads/Emulation-Moves-Into-4-State-Logic-and-Real-Number-Modeling-.pdf) (DVCon).
- S. Ermon et al., *Uniform Solution Sampling Using a Constraint Solver As an Oracle*, [arXiv:1210.4861](https://arxiv.org/abs/1210.4861).
