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

## Not changed (recorded candidates)

- **Z3 context per `randomize()`.** In `randomize_z3.sv` and
  `sv_randomize_global_uniform`, `Z3_mk_context` is about 40% of the time,
  plus kernel page-fault churn from releasing and refaulting its memory.
  Reusing a context would likely change which model Z3 `optimize` returns,
  and so the values a fixed seed produces. It needs a determinism study
  before any change.
- **Allocator.** With `GLIBC_TUNABLES=glibc.malloc.tcache_count=1000` the
  UVM workload ran a further ~25% faster before the slab change. The
  remaining per-frame allocations (`vthread_s` deques, scope thread sets)
  are the next target; an allocator swap is not proposed.
- **Event-callback boundary** (`vvp_event_callback_begin/end`, ~5% of
  `rtl_pipe`) moves three maps and two vectors per array-word callback.
