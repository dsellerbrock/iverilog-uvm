# VVP performance research and experiment order

Reviewed 2026-10-20 against current main
`cc25756d187314742d347267c2a513b3e640a7fb`. The Gemini report is useful
for candidate generation; its speedup multipliers are Amdahl projections,
not VVP measurements. No external simulator's speedup is treated as a VVP
prediction.

## What the source already does

- `%prop/index/check` is compiled from its operand string into an owned
  `property_index_data` descriptor when the VVP instruction is loaded
  ([`compile.cc`](../../vvp/compile.cc), [`codes.h`](../../vvp/codes.h),
  [`codes.cc`](../../vvp/codes.cc)). Runtime execution no longer parses the
  string or allocates a dimensions vector. It still pops every declared index
  after invalid metadata and returns X for malformed metadata, X/Z, bounds, or
  arithmetic overflow ([`vthread.cc`](../../vvp/vthread.cc)). PR #599 merged
  this predecode after pinned and post-rebase screens and final gates passed;
  the archived measurements remain historical evidence, not an unimplemented
  opportunity.
- `vpip_vec4_to_int64_saturated` has a one-word 2-state fast path and a fused
  word-plane fallback that checks X/Z, sign extension, and overflow. The
  fallback was measured and merged in #601; `vvp_vector4_t::has_xz()` scans
  the B plane word by word, while `add` and `sub` already use native word
  arithmetic with a one-word path. There is no broad 2-state opcode family.
  The Gemini helper and `raw_*word0()` names do not exist.
- `vvp_vector4_t` stores up to one `unsigned long` per A/B plane inline and
  allocates the planes for wider values. The vthread vec4 stack is a
  `std::vector<vvp_vector4_t>`; pushing copies a value, and popping copies
  then destroys its slot. Reusing the live stack slots' large-value capacity
  is plausible, but widening inline storage changes the representation across
  the whole class. There is no existing two-word inline buffer or read-only
  slice-view type.
- Vector assignment events are already allocated from `assign4_heap`, a slab
  pool. The scheduler still links events into region queues, so a flat queue
  or NBA coalescing is a separate experiment; allocation is not currently a
  general-purpose `malloc` per vector assignment. Last-write-wins by itself
  does not prove that coalescing preserves propagation, callback, and region
  ordering.
- `vvp_net_t::send_vec4` walks the fanout and calls each receiving functor;
  there is no equality check at that dispatch boundary. Some downstream
  functors may already suppress unchanged results. VVP is event-driven, so
  broad static levelization would change the scheduling model. Value-change
  suppression and local levelization need an exact call-tree profile and
  tests for initial propagation, strengths, VPI callbacks, and visible delta
  changes.
- `maybe_dispatch_virtual_method_call_` already memoizes the resolved
  `(runtime class, base method scope) -> (program counter, scope)` target in a
  `std::map`; on a miss it searches `runtime_super()` ancestors. A call-site
  inline cache could only help if profiling shows the map lookup or miss path
  is still hot. The current source does not establish an O(1) subtype check,
  and adding type tags in alleged padding is not justified without measuring
  object layouts and auditing all dynamic-type users.
- `vthread_run` already executes consecutive opcodes in an inner loop, but
  calls each opcode through a function pointer. Fusing selected bytecodes may
  reduce dispatch and temporary vec4 traffic. The loop also handles pausing,
  tracing, thread lifetime pins, and trampoline switches; the suggested
  `musttail` replacement is not a drop-in. Clang's attribute imposes matching
  signatures and trivial-destruction/lifetime constraints.
- `vvp_vector2_t` exists for selected internal paths, but the vthread opcode
  table does not expose a broad `%load/vec2` and 2-state ALU family. Type-based
  specialization is a real compiler/runtime project, distinct from the
  existing dynamic one-word fast path.

## Measurements and next experiment order

- The focused property-access microbenchmark remains below the 10% bar
  (−9.212159%), and its added zero-based/unit-stride fast path was 0.322130%
  worse. The pinned Caliptra mcycle 100–200 screen improved instructions by
  10.259915%; the single post-rebase screen on `845f54a` improved them by
  10.300108%. Focused checks and all 18 broad output comparisons pass;
  pinned-base full gates also pass. The 16 full-JSON failures matched the
  reference and are corrected on main by #595. The post-rebase instruction gate clears; the final correctness gate passed in
  job 1497 and PR #599 has since merged. Do not treat the bounded profile as a
  complete firmware result.
  The final three-run wall table reports every median and spread as supporting
  evidence; the largest candidate spread is 43.445690%.
- `perf record` sampled c339 and current main over matched Caliptra mcycle
  100–600 and 100–5000 windows. The early window was 0.5% slower on main; the
  longer window was 0.094% faster. Neither explains the full-row slowdown. The
  longer profile still shows `of_PROP_INDEX_CHECK`, `of_LOAD_VEC4`, and
  `vpip_vec4_to_int64_saturated` as major paths, but the largest shares shift
  slightly between builds. The archive's QD-BFM commit differs from the
  supervisor's M7 table citation, so provenance remains an open caveat.
- The first converter prototype replaces its per-bit X/Z pre-scan with the
  existing word-wise `vvp_vector4_t::has_xz()` guard. It cuts converter
  inclusive instructions by 45.8852%, but the focused process improves only
  9.6545%, below the 10% screen, so that variant is rejected.
- A follow-up keeps the one-word 2-state fast path and X/Z rejection, then
  extracts the A-plane a machine word at a time instead of calling `value()`
  per bit. On the 100,000-access workload it reduces whole-process instructions
  from 2,342,072,014 to 1,863,201,596 (−20.446443%). The broad Callgrind
  corpus has 18/18 byte-identical outputs; the maximum increase is +0.001880%.
  Default Callgrind crashed in the FST writer's pthread on the reference, so
  the FST pair was run separately with `--fair-sched=yes` on both builds; it
  matched output and differed by −63 Ir. Job 1348 independently passed native
  outputs 18/18, and job 1351 passed signed/unsigned overflow, sign-extension,
  and X/Z index checks. This word-plane follow-up clears the screen on pinned
  base c7eb. `perf stat` instruction events remain unsupported on DAN-DESKTOP.
  The fused X/Z-and-overflow scan measured -20.535627% focused on c7eb; its
  historical broad counts range from -0.026238% to +0.002218%. It measured
  -20.535761% on `374b037e` and -20.535580% on the current measurement pin
  `631b7a869faaa05216d8749224520227b4b23d43`. On the latter, all 18 broad
  outputs match, the largest positive instruction change is +0.000684%, and
  all five correctness gates pass in job 1955. The three-run wall table
  records every spread. Exact-head Fast Linux run 39016147281 and full test.yml run 39016152877 passed on e2b41a7; PR #601 merged as 06553bf. The relevant runtime, benchmark, and build-path diff from that tested head to current main is empty. Job 3383 now ranks the combined
  `of_LOAD_VEC4`/`copy_from_big_` path as the next Caliptra screen; stack-slot
  capacity reuse remains a separate follow-up.
  Broader 2-state opcodes, wider inline storage, NBA coalescing, type tags,
  superinstructions, and JIT work remain separate measured experiments rather
  than assumed consequences of the Gemini projections.

- Slurm job 3383 profiled current main `cc25756d187314742d347267c2a513b3e640a7fb`
  over three 2,000-mcycle Caliptra windows and all 18 corpus workloads, with
  zero lost samples. Caliptra self samples consistently rank `of_LOAD_VEC4`
  first at 9.04–9.39%, followed by `copy_from_big_` at 3.30–3.70% and
  `vthread_run` at 3.25–3.65%. The load symbol alone misses the 10% screen;
  measure the combined load/copy path using instructions. Corpus priorities
  include `vvp_vector4_t::mul` in `wide_vectors` (30.61%), `send_vec4` in
  `rtl_alu` (11.73%), and callbacks in `vpi_callbacks` (15.02%). These are
  sample shares, not speedups. See [job 3383 profile evidence](../../evidence/m3-current-main-profile-cc25756-20261020/README.md).

## Gemini phase audit

| Report phase | What source verification supports | Campaign treatment |
| --- | --- | --- |
| **1: predecode `%prop/index/check`** | Current main stores a parsed descriptor at VVP load time. Runtime still preserves the required pop count and returns X on invalid metadata. | PR #599 merged after pinned and post-rebase screens (−10.259915% and −10.300108% on bounded Caliptra windows), matching focused and broad outputs, and final gates. The 100,000-access microbenchmark was −9.212159%; the bounded windows are instruction screens, not firmware passes. |
| **1: vec4 conversion, word arithmetic, 2-state specialization** | The small 2-state fast path and word-wise add/sub already exist. The converter has explicit wide X/Z and overflow handling; a generalized 2-state opcode family remains unimplemented. | The initial `has_xz()` fallback remained below the 10% process bar. On pin 631b7a8, the fused converter improved the focused process by 20.535580%, passed all 18 broad output checks, and had no broad count increase above 0.000684%. All five correctness gates and the final three-run wall table passed. Exact-head Fast Linux run 39016147281 and full test.yml run 39016152877 passed on e2b41a7; #601 merged as 06553bf. Current main has no relevant runtime, benchmark, or build-path changes from that tested head. Do not infer gains for a new opcode family. |
| **1: allocation reduction** | `vvp_vector4_t` has one inline word per plane; wider values allocate. The vthread vec4 stack is a `std::vector`, and assignment-event objects already use a slab allocator. | First measure stack widths, copies, and allocation counts; prototype live stack-slot capacity reuse. Wider inline storage, read-only slice views, and whole-vector NBA coalescing remain separate experiments with representation, lifetime, and event-order risks. |
| **2: type tags, subtype checks, virtual-call cache** | Dynamic casts exist, but their aggregate count is not a hot-site profile. Class ancestry is walked through `runtime_super()`. Virtual method target resolution already has a memo keyed by runtime class and base method scope. | Profile casts and the existing memo on UVM/Caliptra before changing dispatch. Do not assume tags fit in padding or that subtype lookup is O(1); avoid adding a second cache unless lookup cost is material. |
| **2: top-15 superinstructions and `musttail`** | The current interpreter already runs consecutive opcodes in a loop and invokes their function pointers. No pinned opcode-pair histogram justifies a top-15 list. The loop also owns pause, trampoline, tracing, and thread-lifetime behavior. | Use the pinned pair histogram to select one frequent non-suspending pair. Treat `musttail` as a separate compiler/lifetime experiment, not a drop-in dispatch edit. |
| **3: copy-and-patch JIT and value-change suppression** | A block JIT is a plausible ceiling experiment with interpreter fallback. The general `send_vec4` boundary does not suppress equal values; suppressing events can affect visible deltas, strengths, and VPI/waveform observers. | The isolated Caliptra SHA-256 round spike measured 5.008× over its small function-pointer interpreter, with 0.921% spread and exact RTL output; this is a kernel ceiling, not a VVP speedup. No further JIT work is authorized by this spike. Gate local levelization on the 35% inclusive net-propagation threshold; profile equal-value suppression separately and test observers before a prototype. See [WP14 evidence](../../evidence/wp14-copy-patch-sha256-20261017/README.md). |

The report's per-technique multipliers and stacked 3.2x–5.5x estimate remain
unsupported for VVP. They are projections from profile shares that are not a
matched pinned-base experiment; the shares may overlap and include work a
candidate cannot remove.

Older sampled profiles point to promising functions, but are not the pinned
Callgrind result for this campaign. For example, one Caliptra profile on
`c339` sampled `of_PROP_INDEX_CHECK` at 7.94% and
`vpip_vec4_to_int64_saturated` at 7.15%; the fixed-window `c014` profile
sampled the property check at 8.33%. These identify where to measure next,
not how much a patch will save. The only accepted speed result is an A/B on
the experiment's recorded base.

## Techniques and local fit

| Technique / precedent | Expected gain in VVP | Main risk | First experiment |
| --- | --- | --- | --- |
| Operand predecode for `%prop/index/check` | The pinned Caliptra mcycle 100–200 instruction count fell 10.259915%; after the single rebase to `845f54a`, it fell 10.300108%. The synthetic 100,000-access loop fell 9.212159%. No wall-time gain is claimed. | Malformed `.vvp` metadata, count limits, reverse pop order, invalid dimensions, overflow and descriptor cleanup. | Both instruction screens and final correctness gates passed; PR #599 has since merged. Report wall medians and spreads as supporting evidence. |
| Word-wide vec4-to-int64 conversion | Unknown; an older sample put the converter at 7.15% self time, an upper bound near 1.08x only if all that cost disappeared. | X/Z rejection, arbitrary widths, signed extension, and saturation. | Profile the pinned converter and value widths, then test exact 0/1/X/Z and boundary widths before benchmarking. |
| Type-based 2-state inference and specialized opcodes | Unknown; existing 2-state paths are local, and the pinned opcode profile does not establish a broad 2-state family. | Incorrectly omitting X/Z for values or operators that can produce unknowns, including exceptional arithmetic. | Select one type-proven 2-state operation, compare exact 0/1/X/Z behavior with the four-state fallback, then instruction-screen it on the pinned corpus. |
| Allocation-free 4-state vector storage (first step: stack-slot reuse) | Unknown; wider copies allocate, but the hot-stack share and removable allocation count are not measured. | Object lifetime, aliasing, peak memory, and changed vector representation. | Measure stack depth/width, copies, and allocation counts; prototype capacity retention in live stack slots only. Defer wider inline storage, read-only slice views, and NBA coalescing. |
| Type tags, subtype checks, virtual-call inline caches | Unknown; dynamic casts appear in VVP, but the old 5–7% class/UVM samples do not isolate which casts are hot on the pinned workloads. Virtual target resolution already has a `std::map` memo. | Incorrect downcasts or stale caches across runtime-created handles and class dispatch. | Profile hot casts and the existing memo by call site before changing one closed, measured hierarchy. |
| Hot bytecode-pair fusion | Unknown; possible savings include both indirect calls and intermediate stack/copy work. | Stack effects, jumps, suspension, tracing and scheduler/VPI boundaries. | Use the pinned WP0 opcode-pair histogram, choose one frequent non-suspending pair, and compare instructions plus exact output. Do not start with the proposed top-15 set or `musttail`. |
| Activity / value-change suppression (ESSENT/GSIM ideas) | Unknown; equal-value savings have not been measured in VVP. | Initialization, explicit events, strength changes, VPI callbacks, and waveform visibility. | Profile equal-value sends and downstream wakes on a pinned workload; then test named-net callbacks and VCD/FST before suppressing propagation. |
| Local levelization and process fusion (Verilator/Khronos ideas) | Unknown. Older RTL samples put net propagation around 18–22%, below the 35% inclusive-share gate. | Delta order, glitches, sensitivity events, VPI observability, and cross-cycle rescheduling. | Measure inclusive recv_vec4, send_vec4, and schedule_* cost. Prototype one untapped cone only if the combined share exceeds 35%; compare exact event logs and VCD/FST. |
| Whole-vector NBA coalescing | Unknown; scheduler queue traversal may matter, but vector event objects already use a slab. | FIFO ordering, mixed partial writes, Re-NBA, callbacks and intermediate propagation. | First profile queue traversal and event counts. Only then test an isolated whole-vector case with same-timestep multi-process and partial-write coverage. |
| Copy-and-patch block JIT | The isolated SHA-256 round kernel ran 5.008× faster than a custom function-pointer interpreter at 0.921% spread; the matching full VVP testbench ran in 0.980 s, but the two times are not a direct comparison. No whole-simulator gain is established. | Executable-memory policy, architecture-specific stencils, code size, startup cost and exact VVP scheduling semantics. | Spike complete on one x86-64 host with exact RTL output and an X/Z fallback check. No-go for expansion or runtime integration without a new user instruction. See [WP14 evidence](../../evidence/wp14-copy-patch-sha256-20261017/README.md). |
| Verilator compiled models | No gain inside VVP. A compiled model is a useful RTL-only reference; it changes code generation and may not match the target's feature/semantic contract. | Timing, four-state behavior, VPI/UVM and output compatibility vary by model and options. | Keep as a separate reference comparison, using identical supported inputs and explicit compatibility checks. |
| ESSENT activity-driven static partitions | No direct VVP gain without a new FIRRTL/static-simulation path. Its result is evidence for coarsened activity checks in its own compiled, cycle-accurate model. | Static cycle execution does not preserve every event-driven observation in VVP. | Revisit only after the net-propagation profile clears the 35% gate; first prototype one side-effect-free cone. |
| RepCut parallel partitioning | No validated gain for the single-thread event-driven VVP runtime; it targets full-cycle parallel RTL simulation. | Cross-partition ordering and VPI/DPI/UVM side effects. | No production experiment in this campaign. A separate cycle-only backend would need a compatibility census first. |
| GSIM supernodes / dataflow cleanup | No direct VVP gain without static graph lowering; useful precedent for choosing coarser activity units and removing dead/alias graph work. | Requires a cycle-oriented graph and proofs that removed nodes are unobservable. | Fold into the gated local-cone experiment, not a separate rewrite. |
| Khronos cross-cycle memory fusion | No validated gain in VVP; its method reschedules state access in a cycle-accurate graph. | Reordering across cycles can violate VVP event, testbench, and VPI observations. | Research-only for this runtime. Do not prototype before an explicitly restricted cycle-only backend exists. |

The Gemini report's 3.2x–5.5x stacked estimate and per-technique multipliers
are not carried forward: the profiles overlap, contain non-removable work,
and come from different tools/builds. Likewise, its C++ field names such as
`prop_desc`, `raw_ab_ptr`, `heap_cap_words_`, and `pending_nba_vec4_` are
sketches, not current VVP members.

## A5 experiment order

1. WP3 #593 is merged as `ccaecfe7`. Its instruction screen is −14.079590%,
   all 18 benchmark outputs match, the final three-run wall table records every
   spread, and exact-head Linux, macOS, Windows, and Slurm gates passed.
2. PR #599 is merged. Its pinned and post-rebase Caliptra instruction screens,
   focused checks, broad output comparisons, and final correctness gates passed.
   The former 16 JSON fixture failures matched the reference and were corrected
   by #595. Its three-run wall medians and spreads are supporting evidence.
3. The fused converter remeasurement on pinned base
   `631b7a869faaa05216d8749224520227b4b23d43` passes: focused instructions
   fall 20.535580%, all 18 broad outputs match, and the largest other increase
   is +0.000684%. All five correctness gates pass; final three-run wall support
   is recorded with every spread. PR #601 merged as 06553bf on 2026-10-17. Exact-head Fast Linux run 39016147281 and full test.yml run 39016152877 passed on e2b41a7. The runtime, benchmark, and build-path diff from that tested head to current main is empty.
4. A2's Caliptra regression profile is a completed diagnosis. Matched c339/main
   samples over mcycle 100–600 and 100–5000 did not reproduce the reported
   row slowdown. The archived QD-BFM commit is d1529c9 rather than the cited
   5f15a13; do not repeat until a longer matched window and its inputs are fixed.
5. Both historical word-plane converter screens passed on c7eb. The current
   fused X/Z-and-overflow candidate was remeasured on base `374b037e`: focused
   instructions fell 20.535761%, all 18 broad outputs matched, and no other
   count increased by 2%. Its new regression fixture covers wide signed and
   unsigned conversion, saturation, a 65-bit tail, and X/Z. Full correctness gates passed in job 1733 and the isolated three-run wall
   table is recorded in job 1758. At that earlier checkpoint exact-head CI was
   still pending; the later 631b remeasurement and merged #601 validation are
   recorded above. Job 3383 ranks the combined `of_LOAD_VEC4`/`copy_from_big_`
   path as the next Caliptra screen; consider vec4 stack-slot capacity reuse
   separately after that screen.
6. In phase 2, profile the existing virtual-dispatch memo and hot cast sites.
   Then select one safe bytecode pair from the pinned WP0 histogram; do not
   implement the report's top-15 set or assume `musttail` is drop-in.
7. WP14's isolated SHA-256 copy-and-patch spike is complete: the round kernel
   measured 5.008× over a custom interpreter, with matching RTL output and
   0.921% spread. It does not establish a VVP speedup. The user's M3 decision
   is no WP14/JIT work in this repository; any later JIT attempt belongs in a
   separate user fork after the full implementation.
8. M3 round 2 refreshed current main `cae035642e056644274a01e98d4422ce286685b4`
   in Slurm job 3009, with 2,000-mcycle windows on three Caliptra tests and
   all 18 corpus workloads, pinned to one CPU. Every profile had zero lost
   samples. Caliptra's top remaining samples are `of_LOAD_VEC4` (9.07–9.77%,
   WP4 already merged), `copy_from_big_` (3.01–3.27%), `__dynamic_cast`
   (2.78–3.11%), `vthread_schedule_list` (2.83–3.00%), and `eeq`
   (2.42–2.48%). Corpus leaders include `send_vec4` at 11.11% in `rtl_alu`,
   event callbacks at 11.14% and `send_vec4` at 8.83% in `rtl_pipe`, and
   `vthread_run` at 11.01% in `multi_clock`. WP11's pinned prototype emitted
   zero fused operators; WP12 has no eligible identical-sensitivity group;
   WP9 records zero Caliptra time-list walk steps; WP10's required VVP shape
   is absent; WP13's 18-workload screen was below threshold. WP7 has no
   Caliptra solver share, and WP8's parser work is startup-only. See [cae
   profile evidence](../../evidence/m3-current-main-profile-cae-20261019/README.md)
   and the WP9/WP11/WP12 screens. No external multiplier is treated as a VVP
   speedup prediction.
   A focused MUXZ-chain prototype emitted 64 fused operators and matched
   stable four-state values, but changed the value-change trace on a named
   output; it was rejected before performance measurement. See [the WP11
   screen](../../evidence/wp11-muxz-chain-cae-20261019/README.md).
9. Slurm job 3012 compared campaign base, M2 main, and current main on three
   interleaved 2,000-mcycle windows per test. The three-test geometric mean is
   +29.67% over campaign base but only +1.54% over matched M2 main; the ROM
   median is 9.751 cycles/s with 13.00% spread. The user-requested +25% target
   is not met. The earlier 10.608 ROM rate used a 500-mcycle window; the
   matched 2,000-mcycle M2 rate is 9.717, making the comparable +25% threshold
   12.146 cycles/s. The safe remaining WP5-WP13 screens have no candidate for
   that gain: WP5/WP6 are merged without a Caliptra gain, WP7 has no solver
   samples, WP8 is startup-only, WP9 found no Caliptra queue walks, WP10 lacks
   an eligible netlist shape, WP11 changes a named-net trace, WP12 has no
   matching process sensitivities, and WP13 fell below its 10% screen. See
   [job 3012 evidence](../../evidence/caliptra-m3-throughput-cae-20261019/README.md)
   and the profile-ranked WP rows in the performance plan.
   On the ROM profile, the four largest non-WP4 self-sample shares
   (`copy_from_big_`, `vthread_schedule_list`, `__dynamic_cast`, `eeq`) sum
   to 11.42%. Removing all four entirely would yield an optimistic 1.129×
   Amdahl ceiling (+12.9% on sampled CPU time), below the +25% target. This
   is not a formal instruction-count or whole-simulator ceiling; the
   WP5–WP13 screens found no safe candidate meeting the per-package 10% gate.

10. Slurm job 3274 refreshed profiles on current main `8c95b5cc10fc83d15b47e0364d2d7b4a2e12cac1`, covering the three 2,000-mcycle Caliptra windows and all 18 corpus workloads with zero lost samples. `of_LOAD_VEC4` remains the largest Caliptra symbol at 8.74–11.64% (WP4 is merged); the leading remaining ROM samples are `of_PROP_INDEX_CHECK` 4.53%, `vthread_run` 3.30%, `setarray` 3.26%, `copy_from_big_` 3.04%, and `vthread_schedule_list` 2.78%. The four largest non-WP4 shares (`of_PROP_INDEX_CHECK`, `vthread_run`, `setarray`, `copy_from_big_`) sum to 14.13%, an optimistic 1.164× sampled-CPU Amdahl ceiling (+16.4%), below the +25% goal; `vthread_schedule_list` is next at 2.78%. No Z3 samples appeared in the Caliptra windows. The corpus remains led by `wide_vectors` multiply (31.25%), `rtl_alu` `send_vec4` (16.28%), `io_text` decimal conversion (15.87%), and `vpi_callbacks` event callbacks (14.99%). See [8c95 profile evidence](../../evidence/m3-current-main-profile-8c95b5c-20261020/README.md).

11. Slurm job 3275 compared the campaign base, matched M2 main, and current main `8c95b5c` on three interleaved 2,000-mcycle top-level Caliptra tests, with three repeats each. The three-test geometric mean is +27.84% over campaign base and +0.97% over matched M2 main. The current ROM median is 9.914 cycles/s (12.89% spread), below the requested 13.3 cycles/s goal. The earlier 10.608 rate used a 500-mcycle window; on the matched 2,000-mcycle window, current main is +1.28% over M2 main (9.914 vs 9.789). All 39 firmware inputs and normalized logs matched. The initial job summary carried a stale `cae0356` label; a corrected analyzer was rerun over the archived raw windows. See [job 3275 evidence](../../evidence/caliptra-m3-throughput-8c95b5c-20261020/README.md).

12. M3 WP7 T0 remains merged in PR #828; M5 resumes WP7 on pinned base
   `10f3a0a2509d0852c2556cb6622fb0025121fb2d`. T1 focused checks preserve
   byte-identical outputs: the cached scalar path hits 35/64 range, 40/64
   enum, and 63/64 constant-dist calls. Job 3657's focused Callgrind ratios
   are 1.523x range, 1.604x enum, and 37.037x overlapping constant `dist`.
   The headline `randomize_z3` and `randomize_dv_txn` controls remain T3 and T4.
   Job 3657's full corpus passed: all 18 outputs are byte-identical, the target
   Callgrind ratios are 0.999959x and 1.000019x, and no other workload regressed
   by more than 2%. The histogram confirms T1 handles none of those target
   calls. The earlier UVM output mismatch came from separately compiled
   bytecode embedding different absolute roots; job 3657 compiles once and
   reuses the bytecode across both runtimes. Job 3681 ran the three 2,000-mcycle Caliptra tests on both binaries;
   each had zero `randomize()` calls. The in-job comparator stopped on a
   wall-clock progress heartbeat difference, but the offline analyzer confirmed
   byte-identical functional logs and firmware hashes after normalizing only
   instrumentation timing and source-root paths. T1 has no Caliptra speedup
   opportunity. The 10x goal remains unmet, so continue with T2/T3.
   A follow-up cached the isolated wide `addr` intervals for `randomize_dv_txn`;
   its 400-call seeded trace stayed byte-identical, but target Callgrind
   instructions regressed 8.797406% (0.919140x), above the 2% limit. That
   interval-cache extension was removed. See the
   [rejected T1 interval-cache evidence](../../evidence/wp7-t1-10f3a0a-20261021/attempts/t1-independent-domain/README.md).
   The first T2 small-domain screen replays the current first 64 proposals for
   enumerable two-state components: `randomize_z3` improved 38.02% (1.613x),
   with 282/800 calls on T2; `randomize_dv_txn` stayed T4 and changed +0.000265%.
   The inherited/invalid-graph-guarded 18-workload validation is queued as
   Slurm job 3731 on the same pinned base. Focused job 3735 passed the later
   guarded-zero matcher with byte-identical traces: `randomize_z3` improved
   38.02% (1.613415x; 282/800 T2 calls), while `randomize_dv_txn` remained T4
   and changed +0.000511% (0.999995x). That run did not include the full
   corpus. Focused Slurm job 3742 measured the cumulative T1/T2/T3 stack:
   `randomize_z3` improved 55.62% (2.253425x), while `randomize_dv_txn`
   improved 6.00% (1.063843x) and missed the 10% gate. Both default-seed
   per-draw traces matched; context creations fell from 800 to 33 and 1,000 to
   63. Candidate transaction RSS rose 3.26%. No full-corpus or multi-seed
   validation was run, so the candidate is not ready to promote and the 10x
   goal remains unmet. See [T2 evidence](../../evidence/wp7-t1-10f3a0a-20261021/attempts/t2-small-dom/README.md), [T3 evidence](../../evidence/wp7-t1-10f3a0a-20261021/attempts/t3-context-reuse/README.md), and [solver details](SOLVER.md).
   Focused T3 job 3752 measured a bounded per-context isolated-factor cache on
   the same pin. Default-seed outputs matched, but the result was effectively
   unchanged from job 3742: 2.253642x on `randomize_z3`, 1.063667x on
   `randomize_dv_txn`, and +3.69% transaction peak RSS. It missed the 10% DVT
   gate, so the analysis cache is rejected and the full corpus was not run.
   The DVT inclusive profile assigns 23.38% to repeated isolated-domain count
   work. T1 job 3759 tried a positive-only cache keyed by the full active
   assertion list, but recorded zero hits and no additional target speedup;
   that key is too narrow across per-draw pins. Job 3763 keyed by the exact
   isolated factor AST, subject, width, and cap, hit 874/1,000 DVT calls, and
   preserved default-seed outputs. Callgrind improved `randomize_z3` 2.254952x
   and `randomize_dv_txn` 1.453790x. The screen passed; multi-seed and full-
   corpus validation remain. See the
   [profile](../../evidence/perf-research-20261014/profiles/randomize_dv_txn.txt),
   [job 3763](../../evidence/wp7-t1-10f3a0a-20261021/attempts/t1-factor-count-cache/artifacts/job-3763/),
   and [job 3759](../../evidence/wp7-t1-10f3a0a-20261021/attempts/t1-positive-count-cache/artifacts/job-3759/)
   and [solver details](SOLVER.md).
   Bitwuzla's
   hard QF_BV microbenchmark advantage does not close its soft/dist/solve-before
   gaps, so Z3 remains the full-semantics recommendation; no seed or
   distribution change is authorized. See [SOLVER.md](SOLVER.md), [M3 WP7
   evidence](../../evidence/wp7-tiered-rand-8c95-20261020/README.md), and [M5
   T1 evidence](../../evidence/wp7-t1-10f3a0a-20261021/README.md).
   The frozen job-3763 candidate is now validated on its pinned base: eight
   seeds matched byte-for-byte; the full 18-workload screen improved
   `randomize_z3` 2.253387x and `randomize_dv_txn` 1.454097x, with no other
   workload over the 2% regression limit; job 3769 passed the full correctness
   gates. The three Caliptra cases made zero randomize calls and their
   normalized functional logs and firmware hashes matched. FST required two
   clean Callgrind pairs because Valgrind intermittently segfaulted; failed
   partial profiles were excluded. The M5 10x target remains unmet. See the
   [final WP7 validation](../../evidence/wp7-t1-10f3a0a-20261021/validation/corpus-r11/).
13. Slurm job 3383 on main `cc25756d` was re-screened inclusively for WP13 on
   the pinned M4 base `fb584a251`. Across the three Caliptra tests, the
   deduplicated union of vector4-plane, arithmetic, copy, construction,
   comparison, resize, propagation, and net-functor samples is 45.53–47.50%,
   an ideal 1.836–1.905x Amdahl ceiling (1.869x equal-weight combined).
   Generic load/store dispatch is reported separately and not credited. A
   narrow elaboration-proven unforced `.net/2u` wire-read prototype measured
   −0.87% over three tests and was rejected; the all-`vec4_value` upper bound
   is 6.61–6.96% by symbol before restricting to eligible wires. See
   [inclusive WP13 evidence](../../evidence/m4-wp13-two-state-fb584-20261020/README.md)
   and [profile source](../../evidence/m3-current-main-profile-cc25756-20261020/README.md).

WP1's prior screen was −3.31% `behav` instructions on its own pinned base,
below the 10% keep threshold; do not repeat it unless its runtime code changes.
Keep one active A5 PR and one pinned base per WP. Record that SHA in each
evidence directory and PR table. Rebase once, immediately before merge, and
remeasure only if the final runtime/benchmark/build-path diff requires it.


## M4 structural screens

The M4 measurement pin is fb584a251dd4cc91e56a75be662ccd5ee05c64e9. Slurm job 3383 profiled the same hot VVP load, scheduling, and net-propagation source paths on cc25756d; the intervening runtime diff is confined to class-object constraint tracking, performance counters, and the Z3 solver.

The inclusive WP13 screen on pinned base `fb584a251` gives a 1.836–1.905x ideal ceiling across the three Caliptra profiles after deduplicating overlapping sample stacks (1.869x equal-weight combined). The 68 overlapping rows include vector construction/destruction, send/receive propagation, `copy_from_big_`, `vec4_value`, arithmetic, logic, comparison, resize, and wire/array propagation. Only an elaboration-proven, unforced `.net/2u` `vvp_wire_vec4` read could use the prototype; the other generic vector and propagation rows remain unchanged. The corrected X/Z force-fallback fixture passed on the candidate, but its three-test A/B measured −0.87% geometric mean, so the prototype was rejected. Job 3570 measured the pinned base at 10.547 cycles/s and the candidate at 10.455 cycles/s; both are below the 14.884 cycles/s target. WP12 has no eligible identical-trigger process group; `multi_clock`'s 15.65% `vthread_run` share comes from 32 processes with distinct clocks, while Caliptra's entire `vthread_run` share is 3.25–3.65%. WP11 has no group to levelize, and the earlier MUXZ candidate changed an observable delta trace. These are limits for the screened paths, not a global VVP ceiling. Details and throughput table are in [M4 closeout evidence](../../evidence/m4-structural-closeout-fb584-20261020/README.md).

## Sources

- User-provided [Gemini deep-research report](https://share.gemini.google/nMPfVgUPaQoS), treated as candidate input.
- [Verilator simulation and performance guide](https://verilator.org/guide/latest/simulating.html) and [timing-option reference](https://verilator.org/guide/latest/exe_verilator.html).
- Beamer and Donofrio, [ESSENT: exploiting low activity factors](https://escholarship.org/uc/item/64x147r1).
- Wang and Beamer, [RepCut](https://escholarship.org/uc/item/1345b80b).
- [GSIM](https://arxiv.org/abs/2508.02236).
- Zhou et al., [Khronos](https://ir.pku.edu.cn/handle/20.500.11897/705639), MICRO 2023.
- Ertl et al., [vmgen: a generator of efficient virtual machine interpreters](https://onlinelibrary.wiley.com/doi/pdf/10.1002/spe.434).
- Xu and Kjolstad, [Copy-and-Patch Compilation](https://compilers.stanford.edu/publications/copy-and-patch/).
- [Clang `musttail` constraints](https://clang.llvm.org/docs/AttributeReference.html#musttail).
- [VVP runtime guide](https://steveicarus.github.io/iverilog/developer/guide/vvp/vvp.html).
