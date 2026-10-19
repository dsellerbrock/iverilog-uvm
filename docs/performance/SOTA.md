# VVP performance research and experiment order

Reviewed 2026-10-17 against the pinned A5 source base
`c7ebca768c21c251d9c165c9aff0e363768030b1`. The Gemini report is useful
for candidate generation; its speedup multipliers are Amdahl projections,
not VVP measurements. No external simulator's speedup is treated as a VVP
prediction.

## What the source already does

- `of_PROP_INDEX_CHECK` is registered as an `OA_STRING` instruction. At every
  execution it parses `cp->text`, resizes a local `std::vector` of dimensions,
  pops the corresponding index values, and computes the flat index
  ([`compile.cc`](../../vvp/compile.cc), [`vthread.cc`](../../vvp/vthread.cc)).
  This is a real predecode target. The runtime also defines behavior for bad
  counts and malformed dimensions: the count may determine how many stack
  values are popped even when later metadata is invalid. A cached descriptor
  must preserve that behavior. `vvp_code_s` has no `prop_desc` field; it has a
  three-word instruction with a pointer union and an existing owned-data
  cleanup pattern (`container_data` in [`codes.h`](../../vvp/codes.h) and
  [`codes.cc`](../../vvp/codes.cc)).
  The prototype was built and passed a 32-case focused check, including
  malformed metadata. Predecode alone reduced the 100,000-access Callgrind
  count to 1,052,269,912 (−6.744313%); packed result construction improved
  that to 1,024,423,467 (−9.212159%). A single-dimension fast path worsened
  it to 1,027,723,440 (−8.919704%). The 100,000-access microbenchmark remains
  below the 10% bar. A paired Caliptra mcycle 100–200 screen on the same pin
  measured 184,080,599,400 → 165,194,086,031 instructions (−10.259915%) for
  predecode plus packed result construction. The 18-workload Callgrind outputs
  all matched, with no non-target instruction increase above +0.038453%; the
  focused legacy and JSON lists passed 19/19 each, and malformed metadata
  returned X for all 16 reads. Its fixed ECC inputs and visible simulation
  prefix matched; the window intentionally stops before testbench completion,
  so this is a screen, not a firmware pass. Pinned-base full gates passed in
  job 1457, with zero JSON failure delta versus the reference; A4 confirmed
  the 16 shared JSON failures were existing fixture defects corrected by #595.
  The candidate was rebased once onto `845f54a5724c4d2af13dde40eca6d290c80c41d9`.
  Because the pinned-path diff changed 12 `vvp/` files, Slurm job 1496 rebuilt
  both sides on that base and measured 183,325,396,223 → 164,442,681,700
  Callgrind instructions (−10.300108%) over the same Caliptra mcycle 100–200
  window. Generated inputs and visible output matched, and the inverted
  regression assertion was rejected. The VPI screen ends the simulation at
  mcycle 200; this is not a firmware pass. Final post-rebase correctness gates
  passed in job 1497; PR #599 has since merged. The run is in
  [Caliptra evidence](../../evidence/wp2-predecode-caliptra-c7eb-20261015/attempt-1420/README.md);
  earlier variants remain in [focused evidence](../../evidence/wp2-predecode-c7eb-20261015/README.md).
- `vpip_vec4_to_int64_saturated` already has a fast path for a 2-state value
  that fits in one native word (`small_2state_word`). Its fallback scans bits
  to reject X/Z and handle arbitrary-width signedness and saturation.
  `vvp_vector4_t::has_xz()` scans the B plane a machine word at a time; it is
  not a single-instruction guard for wide vectors. `vvp_vector4_t::add` and
  `sub` already use native word arithmetic and reject X/Z by checking the B
  plane, including a one-word fast path. The report's broad arithmetic rewrite
  is therefore not new work. A useful target is the converter's bit-wise
  fallback, after profiling its widths and value patterns; the proposed helper
  and `raw_*word0()` names in the Gemini sketch do not exist.
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
  records every spread. Exact-head Fast Linux run 39016147281 and full test.yml run 39016152877 passed on e2b41a7; PR #601 merged as 06553bf. The relevant runtime, benchmark, and build-path diff from that tested head to current main is empty. The next separate target is
  `of_LOAD_VEC4`; stack-slot capacity reuse follows.
  Broader 2-state opcodes, wider inline storage, NBA coalescing, type tags,
  superinstructions, and JIT work remain separate measured experiments rather
  than assumed consequences of the Gemini projections.

## Gemini phase audit

| Report phase | What source verification supports | Campaign treatment |
| --- | --- | --- |
| **1: predecode `%prop/index/check`** | The pinned base parses the operand string and builds a local dimensions vector at execution. The stack-pop contract continues after invalid dimensions, so a descriptor must retain the parsed count and malformed-metadata behavior. | Pinned Caliptra screen: −10.259915%; post-rebase screen on `845f54a`: −10.300108%. The 100,000-access microbenchmark is −9.212159%. Focused checks and all 18 broad outputs match; pinned-base and final post-rebase full gates pass. PR #599 has since merged; the pinned and post-rebase measurement evidence remains archived. Both Caliptra screens end at mcycle 200 and are not firmware passes. |
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
   recorded above. Next screen `of_LOAD_VEC4` and vec4 stack-slot capacity reuse separately.
6. In phase 2, profile the existing virtual-dispatch memo and hot cast sites.
   Then select one safe bytecode pair from the pinned WP0 histogram; do not
   implement the report's top-15 set or assume `musttail` is drop-in.
7. WP14's isolated SHA-256 copy-and-patch spike is complete: the round kernel
   measured 5.008× over a custom interpreter, with matching RTL output and
   0.921% spread. It does not establish a VVP speedup; stop here. Any further
   JIT work requires a new user instruction. Measure value-change suppression
   only if inclusive net propagation clears the 35% gate.
8. M3 round 2 refreshed the current-main profile on `c344d201` in Slurm job
   2783. Across the three Caliptra tests, the largest remaining sampled VVP
   symbols are `copy_from_big_` (3.07–3.28%), `__dynamic_cast` (3.08–3.25%),
   `vthread_schedule_list` (2.84–2.98%), and `eeq` (2.27–2.54%). In the
   broader corpus, `send_vec4` is 15.35% in `rtl_alu`, event callbacks and
   `send_vec4` are 9.89% each in `rtl_pipe`, and `vthread_run` is 12.30% in
   `multi_clock`. Screen in this order: WP11 net sends/cones, WP12 scheduling,
   WP7 randomization, then WP8 load/compile. WP8 is startup work and cannot
   establish the steady-state Caliptra mcycle target. WP10's constant-shift
   attempt did not change generated bytecode and was stopped before timing;
   WP9's observed scheduler walk is too short for the 10% gate; WP13's prior
   current-main screen was below threshold. The measured profile is in
   [c344 evidence](../../evidence/m3-current-main-profile-c344-20261018/README.md);
   no Gemini multiplier is treated as a VVP prediction.

WP1's prior screen was −3.31% `behav` instructions on its own pinned base,
below the 10% keep threshold; do not repeat it unless its runtime code changes.
Keep one active A5 PR and one pinned base per WP. Record that SHA in each
evidence directory and PR table. Rebase once, immediately before merge, and
remeasure only if the final runtime/benchmark/build-path diff requires it.

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
