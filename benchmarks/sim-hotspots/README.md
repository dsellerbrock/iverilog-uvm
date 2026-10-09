# Simulation hot-spot survey (2026-10-09)

Profile-driven runtime work on VVP. Each change keeps the simulated result
byte-identical; it removes interpretation overhead, not semantics.

## Method

1. Built the tree with `-O2 -g -fno-omit-frame-pointer` on Linux x86-64
   (Ubuntu 24.04, GCC 13, Bison 3.8.2, flex 2.6.4, Z3 4.8) and kept a copy of
   the unmodified install as the reference runtime.
2. Wrote six small workloads (this directory), one per simulation style:

   | File | Workload |
   | --- | --- |
   | `rtl_pipe.sv` | 128-stage pipeline: continuous-assign XOR/shift/add, NBAs |
   | `rtl_alu.sv` | 64 ALU lanes: `+ - << >> & | ^ == <`, muxes, FSM, memory |
   | `behav.sv` | Automatic function calls, loops, array traffic |
   | `classq.sv` | Class objects, virtual methods, mailbox, queue |
   | `uvm_traffic.sv` | UVM 1800.2 env: sequence, driver, DUT, monitor, scoreboard (5,000 items) |
   | `randomize_z3.sv` | `randomize()` through the Z3 path |

3. Sampled each with `perf record -g` and attributed time by caller with
   `perf script`; `valgrind --tool=callgrind` gave exact counts for a
   300-item UVM run. A graphify AST graph of `vvp/` was used to navigate from
   hot symbols to their callers and owners.
4. For each hot spot, wrote the smallest change that keeps the existing
   behavior, then compared full simulation output against the reference
   runtime.

`run.sh <reference-vvp> <candidate-vvp> [runs]` rebuilds the workloads with
the `iverilog` on `PATH`, times both runtimes, and fails if any output differs.

## Hot spots found and changes

| Area | Profile evidence | Change |
| --- | --- | --- |
| Vector logic functors (`AND/OR/XOR/NAND/NOR/XNOR`) | `vvp_fun_xor::calculate`, `set_bit`, bit `operator^`: ~48% of `rtl_pipe` | Same-width inputs use the existing word-wide 4-state `vvp_vector4_t` operators; mixed widths keep the bit loop |
| `.arith/sum`, `.arith/sub` | `add_with_carry` + `recv_vec4`: ~19% of `rtl_pipe` | Same-width operands use `vvp_vector4_t::add/sub` (all-X on any X/Z, as before) |
| `.cmp/eq`, `.cmp/eeq`, `.cmp/nee`, `.shift/l`, `.shift/r(s)` | bit loops in `rtl_alu` | `eeq`/`has_xz` word checks; shifts use word part-select and `set_vec`; X/Z keeps the bit loop |
| Deferred-assertion flush on every wake | `pointer_is_live` + `dynamic_cast` in `vthread_run` for pure RTL | Skip the process lookup while no deferred-assertion report is pending anywhere |
| Automatic-context registries | four `unordered_map/set` keyed by context; 8 node allocations per call frame | One record per context (owner, refcount, live, generation) kept across frame reuse, plus an exact direct-mapped lookup cache |
| Object liveness check on every handle copy | `vvp_object::pointer_is_live`: 11% of `classq` | Exact direct-mapped cache in front of the live-object hash set |
| Context release | `dynamic_cast` per scope item on every `%free` | `automatic_hooks_s::release_instance` virtual |
| Stacked-context cycle checks | `std::set` node per visited frame | Inline 32-entry visited array, spilling to `std::set` |
| `%callf` | two `vpiFullName` strings built per call, used only by traces | Built on first use |
| Virtual method dispatch | string label build + map lookups per call | Memoize `(class, base method) -> (pc, scope)`; label tables are frozen before simulation; tracing bypasses the memo |
| Thread frames | `vthread_s` is 3,488 bytes, above glibc's small-block caches; `vvp_process` built two `std::deque`s per frame | Slab free list for `vthread_s` storage (zero-filled); `std::vector` for the process's rarely used report queues |
| Design load | `yylex` 15-22% and symbol lookups 26% of a UVM load | flex `-Cf` tables for the VVP lexer; symbol slots keep their hash so probes skip `strcmp` |

## Results

Wall seconds, median of 3, same compiled `.vvp` files for both runtimes
(`run.sh`).

Linux x86-64, 4 vCPU, idle host. Reference: `main` at f3f394f3 built with
the same flags. Candidate: this branch merged with `main` at 4b3f3424 (no
`vvp/` changes on `main` in between).

| Benchmark | Reference | Candidate | Speedup | Output |
| --- | ---: | ---: | ---: | --- |
| `rtl_pipe` | 4.71 s | 1.20 s | 3.92x | identical |
| `rtl_alu` | 6.34 s | 3.62 s | 1.75x | identical |
| `behav` | 6.76 s | 4.17 s | 1.62x | identical |
| `classq` | 9.73 s | 5.59 s | 1.74x | identical |
| `uvm_traffic` (5,000 items) | 30.35 s | 14.26 s | 2.13x | identical |
| `randomize_z3` | 5.67 s | 5.36 s | 1.06x | identical |
| UVM library load only (`run_test` removed) | 1.70 s | 1.35 s | 1.26x | identical |

The load row is the median of three runs of `uvm_traffic.sv` with
`run_test` replaced by `$finish`; it is included in the `uvm_traffic` time.
These are single-host measurements, not a cross-platform claim; macOS ARM64
has a different allocator, so the thread-frame gains there may differ.

## Correctness evidence

- Two new exhaustive 4-state regressions,
  `ivtest/ivltests/vvp_vec4_functor_logic.v` (1,026 rows) and
  `vvp_vec4_functor_arith.v` (2,304 rows), cover 2/4/8/64/70-bit widths,
  2-4 input gates, signed shifts, X/Z shift counts and over-shifts. Their gold
  files were generated by the reference (bit-serial) runtime.
- Every benchmark's full output, including the UVM report, matches the
  reference runtime.

## Event ordering audit

Every change was checked against the IEEE 1800-2017/2023 scheduling rules
(4.4 regions, 4.6 determinism, 4.7 nondeterminism):

- The functor changes compute the same value and send it once, as before;
  functor scheduling (`schedule_functor`) and the event regions are untouched.
- The deferred-assertion flush skip only skips a flush that has nothing to
  discard; Observed-region maturing is unchanged (16.4).
- Context records, the liveness cache, `release_instance`, the visited set,
  lazy names, the dispatch memo and the load changes do not schedule anything.
- **Allocation-order dependence.** Event-control waiters wake in the order
  they began waiting (an existing rule in `vthread_schedule_list`). Three
  other waiter sets — `process::await()` waiters, class-property `wait()`
  waiters, and virtual-interface multi-signal waits — iterated a
  `std::set<vthread_t>`, i.e. in **pointer order**, so their relative wake
  order depended on where the allocator placed each thread (it already
  differed between allocators and platforms, and the `vthread_s` slab would
  change it again). They now wake in wait order too, and `disable <scope>`
  kills a scope's threads oldest first. Pinned by
  `ivtest/ivltests/sv_waiter_set_wake_order.v` (2017/2023); the unmodified
  runtime fails it (`prop order 210354`, `vif order 012345`). §4.7 allows
  any order here; the point is a stable, allocation-independent one.

## Constrained randomization (Z3)

`randomize_dv_txn.sv` is a typical bus transaction (`dist`, `inside` ranges,
alignment, implications); 1,000 calls took 76 s (76 ms per call).

| Finding | Change | Effect |
| --- | --- | --- |
| A 32-bit variable with more legal values than the enumerators handle was chosen by minimizing `x ^ random_target` in Z3 `optimize`. That is not uniform: for `x inside {0, [32'h1000:32'h1FFF]}` it returned `x == 0` in 208 of 400 draws (uniform: about 0.1). | The existing exact interval sampler was gated to widths above 32 bits and to classes with a single rand variable. It now applies to any width when the variable is an isolated factor (its hard clauses mention no other free variable), which the sampler proves before use. | Correct distribution (IEEE 1800-2017 18.5.10 / 2023 18.5.9); 0 of 400 above. |
| That sampler issued every query against the whole problem and walked every interval, so a strided set (`addr[1:0] == 0`) exceeded its query budget and `randomize()` failed. | Legality tests evaluate the isolated factor at a constant through one reusable model; range queries use a solver holding only the factor; proposals are drawn uniformly from the legal hull `[min, max]` (exact rejection sampling) before any interval walk. | Strided and clustered domains sample in a few checks. |
| Sparse enumeration collected 65 models and then discarded them whenever a variable had more than 64 legal values. | A cheap exact proof (more than 64 legal values found by evaluating the isolated factor near one model value) skips that probe. Identical outcome. | Same results, fewer solver calls. |
| A wide or randc variable coupled to another variable was enumerated by blocking each model value; every `get_model` then re-checked all earlier blocking clauses, so cost grew quadratically (an 11-bit randc with 1,025 legal values took 0.73 s per `randomize()`). | The same model-guided range walk, capped at the same count, with the set returned in ascending order. The legal set is identical; picks no longer depend on Z3's model order, so they are the same across Z3 versions. | 5.9 s → 1.4 s for 8 calls of the coupled-randc reducer, same values. |
| Small domains (up to 1,024 values) were probed one value at a time (256 checks for an 8-bit variable). | Model-guided interval splitting returns the same ascending list with about 2F+1 checks for F legal values. | Same results. |

Result: 76 s → 25 s for 1,000 `randomize_dv_txn` calls, with the address
distribution corrected. `sv_randomize_isolated_wide_uniform.v` (2017/2023)
pins the distribution; the unmodified runtime fails it.

### Attempt ledger

| Idea | Measured | Verdict |
| --- | --- | --- |
| Range queries as `check_assumptions` instead of push/assert/pop | 10.79 s → 10.75 s (bias case) | reverted, noise |
| Keep freed memory (mallopt) around `Z3_mk_context` | 2.97 → 2.75 ms per context | not adopted, 7% |
| Build the next fresh Z3 context on a background thread | 3.0 → 3.6–4.8 ms per iteration | rejected, slower (lock contention) |
| Reuse one Z3 context across calls | not built | rejected: values picked from model-ordered lists would depend on unrelated earlier randomizations, breaking random stability (18.14) |
| Delete each Z3 context on a background thread | 3.0 → 3.5 ms per call | rejected, slower (allocator contention) |
| `auto_config=false` context parameter | 2.9 → 2.5 ms per context | not adopted: it changes Z3's solver configuration, so models and hard-problem behavior can change |

`Z3_mk_context` remains about 2.7 ms per `randomize()` that reaches Z3 (one
fresh context per call keeps calls independent). It dominates the
statistical `sv_randomize_global_uniform` test (DD-110), which now completes
and passes but still exceeds the 300-second CPU guard on this host.

## Not changed (recorded candidates)

- **Model-order independence.** Sparse-domain picks index a list in Z3
  model order, so seeded values depend on Z3 internals (and version).
  Sorting those lists would make them version-independent and would allow
  context reuse; it changes seeded values once, so it is left for a separate
  decision.
- **Coupled wide variables** (constraints linking a wide variable to another
  free variable) still use the XOR-distance objective, which is not uniform.
- **Allocator.** With `GLIBC_TUNABLES=glibc.malloc.tcache_count=1000` the
  UVM workload ran a further ~25% faster before the slab change. The
  remaining per-frame allocations (`vthread_s` deques, scope thread sets)
  are the next target; an allocator swap is not proposed.
- **Event-callback boundary** (`vvp_event_callback_begin/end`, ~5% of
  `rtl_pipe`) moves three maps and two vectors per array-word callback.
