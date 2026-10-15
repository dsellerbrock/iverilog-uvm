# VVP performance research and experiment order

Reviewed 2026-10-15 against the pinned A5 source base
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
  The WP2 worktree has an uncommitted prototype using a new
  `property_index_data` member in that union; it is not part of the pinned
  baseline and has not passed the target build, equivalence, or performance
  screen yet.
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

## Gemini phase audit

| Report phase | What source verification supports | Campaign treatment |
| --- | --- | --- |
| **1: predecode `%prop/index/check`** | The pinned base parses the operand string and builds a local dimensions vector at execution. The stack-pop contract continues after invalid dimensions, so a descriptor must retain the parsed count and malformed-metadata behavior. | Screen the existing predecode prototype on the pinned base. The old sampled handler share gives an Amdahl ceiling of about 1.09x even if the whole handler disappeared; that is not a prediction and predecode removes only part of it. Keep only on measured campaign gates. |
| **1: vec4 conversion, word arithmetic, 2-state specialization** | The converter's small 2-state fast path and word-wise `has_xz`, add, and sub already exist. Only the converter fallback and the absence of a broad 2-state opcode family remain plausible targets. | Profile the converter and `of_LOAD_VEC4` as separate #536 candidates. Prototype one measured path; do not rewrite the existing word arithmetic or infer a gain from another simulator. |
| **1: allocation reduction** | `vvp_vector4_t` has one inline word per plane and wider copies allocate. The vthread vec4 stack is a `std::vector`, so retaining capacity in its live slots is plausible. Assignment-event objects already use a slab allocator, although their region queues remain linked. | First measure stack widths, copies, and allocation counts. Start with stack-slot reuse only. Wider inline storage, read-only slice views, and NBA coalescing are separate changes with representation, lifetime, and event-order risks. |
| **2: type tags, subtype checks, virtual-call cache** | Dynamic casts exist, but their aggregate count is not a hot-site profile. Class ancestry is walked through `runtime_super()`. Virtual method target resolution already has a memo keyed by runtime class and base method scope. | Profile casts and the existing memo on UVM/Caliptra before changing dispatch. Do not assume tags fit in padding or that subtype lookup is O(1); avoid adding a second cache unless lookup cost is material. |
| **2: top-15 superinstructions and `musttail`** | The current interpreter already runs consecutive opcodes in a loop and invokes their function pointers. No pinned opcode-pair histogram justifies a top-15 list. The loop also owns pause, trampoline, tracing, and thread-lifetime behavior. | Use the pinned pair histogram to select one frequent non-suspending pair. Treat `musttail` as a separate compiler/lifetime experiment, not a drop-in dispatch edit. |
| **3: copy-and-patch JIT and value-change suppression** | A block JIT is a plausible ceiling experiment with interpreter fallback. The general `send_vec4` boundary does not suppress equal values; suppressing events can affect visible deltas, strengths, and VPI/waveform observers. | Measure a JIT ceiling in isolation, including compile/startup cost and exact output. Gate suppression or local levelization on the existing 35% inclusive net-propagation threshold and restrict any prototype to proven untapped cones. |

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
| Operand predecode for `%prop/index/check` | Unknown. The older sampled share gives an Amdahl ceiling of about 1.09x if the entire handler vanished; predecode removes only part of it. | Malformed `.vvp` metadata, count limits, reverse pop order, invalid dimensions, overflow and descriptor cleanup. | Callgrind the pinned Caliptra run; attribute parse, allocation and value-conversion costs. Prototype a typed descriptor only if the inclusive share justifies it; preserve the legacy pop contract. |
| Word-wide vec4-to-int64 and proven 2-state operations | Unknown; an older sample put the converter at 7.15% self time, an upper bound near 1.08x only if all that cost disappeared. | X/Z rejection, arbitrary widths, signed extension, saturation, and operators that can produce X. | Profile the pinned converter, record widths and state patterns, then test exact 0/1/X/Z and boundary widths before benchmarking. Keep the existing fast path. |
| Allocation reuse for the vthread vec4 stack | Unknown; large vec4 copies and allocation show up in older profiles, but not every allocation is on the hot stack. | Object lifetime, aliasing, peak memory, and vector representation changes. | Measure stack depth/width and allocation counts. Prototype capacity retention in stack slots only; defer slice views and wider inline storage until that screen wins. |
| Type tags, subtype checks, virtual-call inline caches | Unknown; dynamic casts appear in VVP, but the old 5–7% class/UVM samples do not isolate which casts are hot on the pinned workloads. Virtual target resolution already has a `std::map` memo. | Incorrect downcasts or stale caches across runtime-created handles and class dispatch. | Profile hot casts and the existing memo by call site before changing one closed, measured hierarchy. |
| Hot bytecode-pair fusion | Unknown; possible savings include both indirect calls and intermediate stack/copy work. | Stack effects, jumps, suspension, tracing and scheduler/VPI boundaries. | Use the pinned WP0 opcode-pair histogram, choose one frequent non-suspending pair, and compare instructions plus exact output. Do not start with the proposed top-15 set or `musttail`. |
| Activity suppression and local levelization (ESSENT/GSIM ideas) | Unknown. Older RTL samples put net propagation around 18–22%, below the tech lead's 35% inclusive-share gate for a levelization prototype. | Delta ordering, glitches, initialization, strengths, VPI callbacks and waveform visibility. | Measure inclusive `recv_vec4`, `send_vec4`, and `schedule_*` cost on the pinned workload. Prototype one untapped cone only if the combined share exceeds 35%; compare VCD/FST and callback behavior. |
| Whole-vector NBA coalescing | Unknown; scheduler queue traversal may matter, but vector event objects already use a slab. | FIFO ordering, mixed partial writes, Re-NBA, callbacks and intermediate propagation. | First profile queue traversal and event counts. Only then test an isolated whole-vector case with same-timestep multi-process and partial-write coverage. |
| Copy-and-patch block JIT | A measured ceiling is required; the paper's gains on SQL/WebAssembly workloads do not predict VVP. | Executable-memory policy, architecture-specific stencils, code size, startup cost and exact VVP scheduling semantics. | Spike on one hot straight-line block with interpreter fallback; measure Callgrind instructions, compile/startup cost and output equality. No productionization or LLVM dependency without supervisor approval. |
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

1. Finish WP3 `of_CAST2` on pinned base
   `c7ebca768c21c251d9c165c9aff0e363768030b1`; PR #593 is open and the
   instruction gate and final three-run wall table are complete. A4's JSON
   fixture fixes merged in #595. Rebase once onto `1814cc6483e420321a8243185ac52b2d7b5380bc`;
   the required runtime/build-path diff is empty, so the timing evidence holds.
   Finish final-head correctness gates and CI before merge.
2. Profile A2's M7 row 14, `smoke_test_dma_aes_gcm_short_1_dword`, on c339 and
   `3335fe7ec` to investigate its 7.023 vs 6.384 cycles/s result. Use `perf
   record` sampling on both builds over the same fixed mcycle window; do not
   use Callgrind at Caliptra speed. The archived row records QD-BFM `d1529c9`,
   while the supervisor note cites table commit `5f15a13`; retain the recorded
   row inputs and note the provenance mismatch. The mcycle-600 profile is an
   early-path diagnosis, not a full-test timing result.
3. Screen property-index predecode on the pinned base. Keep it only if it
   clears the campaign's 10% Caliptra instruction gate.
4. Screen the #536 converter/2-state path and allocation reuse as separate
   candidates. Prioritize the converter fallback or `of_LOAD_VEC4` only where
   pinned Callgrind confirms the hot path; begin allocation work with vec4
   stack-slot capacity reuse.
5. In phase 2, profile the existing virtual-dispatch memo and hot cast sites.
   Then select one safe bytecode pair from the pinned WP0 histogram; do not
   implement the report's top-15 set or assume `musttail` is drop-in.
6. In phase 3, measure value-change suppression only if inclusive net
   propagation clears the 35% gate. Run copy-and-patch as an isolated
   speed-of-light spike, report its measured ceiling, and stop before
   productionizing it.

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
