# 2026-09-28 — VVP single-core and multicore performance assessment (Caliptra / Adams Bridge)

Level 4 historical evidence. Revision-scoped to fork HEAD `7a04009f` plus the
`claude/icarus-vvp-optimization-p3ejxh` changes named below. This log does not
authorize implementation of anything it ranks.

## Scope and provenance

- Task: rank single-core compiler and runtime work against multicore
  scheduling for VVP, with Caliptra as the target workload. Other agents own
  the OpenTitan and Caliptra DV blockers, including the Flash runtime event
  loop. No DV corpus was run.
- Host: Linux x86-64 container with 4 vCPUs, GCC, `-g0 -O2`, serial builds.
  This is not the campaign Mac, so absolute times here are not comparable
  with the handoff numbers. Only paired ratios are reported.
- Compiler/runtime: `local-install` built from this worktree. The baseline
  `vvp` and `vvp.tgt` were built from a clean `7a04009f` worktree. Both
  variants share the same `ivl` front end: `iverilog -B <baseline lib>` for
  the baseline and the default for the new build.
- Workload: `abr_masked_A2B_conv`, `abr_masked_full_adder` and
  `abr_masked_AND` from Adams Bridge `b77e3d899e828d626cfc2a0d26a6b5704cc121e0`,
  the submodule that Caliptra RTL v2.1.2 pins. They were used from a
  disposable clone; the pinned sources were not modified. The A2B file's
  SHA-256 prefix is `78b4d87aaf1f8533`.
- Reducer: [`tb_a2b.sv`](../../../evidence/vvp-hotpath-perf-20260928/tb_a2b.sv)
  runs four `WIDTH=46` instances with LFSR stimulus and hashes every output
  per cycle from cycle 100 on.
- Primary metric: callgrind instruction count (Ir) collected only inside
  `schedule_simulate`. It is deterministic and excludes `.vvp` parsing.
  Wall-clock noise on this host was about ±15%, so CPU times are secondary.

## Observations handed off (not re-measured here)

- A frozen 200-edge Caliptra profile shows the Adams Bridge adder hierarchy
  at 68.2% of sampled VVP instructions, with 23,253,012 assignment events.
- Manually expanding the loops cut full-top CPU by 17.6% (median of two
  opposite-order pairs) and made the A2B reducer 2.355× faster. The VVP
  image grew 1.63% and compile time rose from 11.661 to 12.075 s.
- Neutral or negative prior experiments: affine/index prototypes, fused NBA
  offsets, signed short indices, wide-vector reuse, `%addi` increments,
  `-O3`, and `%muli 2` to shift (wrong for X).
- Multicore: a two-worker no-op rendezvous costs 3.4–3.6 µs. The 46 x/y
  bodies take 1.088 ms and the 46 sum bodies 0.445 ms per sampled edge. No
  certified batch meets the go gate (at least 0.5 ms of certified work on at
  least 90 of 100 edges, then at least 5% median end-to-end speedup).

## New observations (this session)

1. **Code shape.** Each of the 46 `gen_full_adders[i]` x/y processes and 46
   sum processes runs every posedge while `rst_n && !zeroize`. The
   `for (int j ...)` loop sits in an implicit block whose index is
   automatic (IEEE 1800-2017/2023 §12.7.1). `tgt-vvp` lowers that block to
   `%alloc` / `%fork` / `%join` / `%free`. That is the "fork/join child body"
   in the handoff. It is not a user `fork`.
2. **Baseline profile** (reducer, 8 cycles, 2.776 G Ir):
   - `%load/vec4` is 23% inclusive. Every `x_reg[i][j-1]` read copies the
     whole 4232-bit `x_reg` before `%part/s` keeps 2 bits.
   - `vpip_vec4_to_int64_saturated` is 8.8% self time; it walks the index
     vector bit by bit.
   - `%cmpi/s` is 7%.
   - Automatic-index loads and stores, through scoped context lookup, cost
     about 12%.
   - NBA application is 16.5%.
   - `%fork` / `vthread_new` is only 2%.
3. **Implemented hot-path changes.** Output hashes are identical in all four
   builds (`d7427ab35c41830a 23f2fa7cd62c91f8 a2b5b4618c4e2666 7b7fa14232b6f2d5`).

   | Simulate-phase Ir, 8 cycles × 4 instances | rolled source | manually unrolled (diagnostic) |
   |---|---:|---:|
   | baseline `7a04009f` | 2.776 G | 1.514 G |
   | this change | 2.056 G (1.35×) | 1.141 G |

   The runtime changes and loop specialization stack. Unrolling still gives
   1.80× on top of this change.
4. **After both changes** (unrolled source plus this change), NBA
   application is 40% of Ir. Each 2-bit NBA re-propagates the whole
   4232-bit vector through the wire filter (`eeq` and copy), the
   `always_comb` any-edge functor (`eeq` and copy), and 46 `.part`
   functors. That is O(N) work per NBA and O(N²) per edge per wide
   variable.
5. **VPI observability of the loop index.** This fork refuses
   `cbValueChange` on the automatic for-init index: "cannot place value
   change callback on automatically allocated variable 'j'". A static
   `integer k` loop index gets one callback per store (8 in the probe).
   Evidence: [probe](../../../evidence/vvp-hotpath-perf-20260928/vpi_auto_index_probe.c),
   [source](../../../evidence/vvp-hotpath-perf-20260928/vpi_auto_index_probe.sv).
6. **Code size and compile time.** This change makes the reducer `.vvp`
   1.2% smaller (4,264,527 to 4,213,130 bytes), with no measurable compile
   time change (3 interleaved pairs, about 0.33 s each). The manually
   unrolled reducer `.vvp` is 72% larger than the rolled one, which is an
   upper bound for full expansion on an A2B-only image. The full-top image
   grew 1.63% in the handoff.
7. **Two unrelated pre-existing defects**, parked as DD-064 (a slice of a
   2-D unpacked array connected to an output array port reads X) and DD-065
   (a two-state variable receives X from an out-of-range part select).

## Ranked recommendation

Inferences are marked. Gains are for the reducer unless stated; the
full-top effect of anything below is **not measured**.

### 1. VVP hot-path fixes — implemented in this branch

- **Boundary:**
  - `tgt-vvp` `draw_select_vec4` emits `%load/vec4/part/{s,u}` or
    `%load/vec4/parti` for a part select of a whole, dimensionless
    `logic`/`bit` signal. It does so only when the base is effect free (a
    whitelist of expression kinds and operators) and no event-expression
    recipe is capturing.
  - The runtime reads only the selected bits: `vvp_signal_value::vec4_part_value`,
    overridden by `vvp_wire_vec4` to honor force masks. It still applies
    both static-call overlays first and falls back to the old helper for
    out-of-range bases.
  - Word-level fast paths cover `vpip_vec4_to_int64_saturated`, `do_CMPS`
    and `%cmpi/s` for fully defined single-word operands. X/Z operands keep
    the original code.
- **Correctness conditions:**
  - The only reordering is evaluating the base before loading the variable,
    which is safe when the base has no side effects.
  - Out-of-range bits are X, and an X/Z base yields all-X (§7.4.6, §11.5.1).
  - Forced bits are read through the filter.
  - Automatic variables use the default full-value path.
  - VPI, NBA and callback behavior are untouched.
- **Tests:** `vvp_load_vec4_part_select_{2017,2023}` passes on both the
  baseline and the new build. It checks against a shift-based reference:
  - dynamic and constant bases, in range and partially or fully out of
    range, in both directions;
  - 1-, 33-, 64-, 66- and 70-bit bases, `INT64_MIN`, and unsigned bit 63;
  - X and Z bases, and X/Z data;
  - a forced net part and its release, and a forced variable and its release;
  - in-range two-state selects and automatic-variable selects;
  - signed compares at 8, 64 and 65 bits and immediate compares.
- **Measured on the reducer:**
  - 1.35× fewer simulate-phase instructions.
  - User CPU over three interleaved 150-cycle pairs: ratios 1.119, 1.110 and
    1.317, median 1.12×.
  - On the unrolled diagnostic, the ratios are 1.043, 1.178 and 1.166,
    median 1.17×.
  - The image is 1.2% smaller.

  Raw data: [results.json](../../../evidence/vvp-hotpath-perf-20260928/results.json).
- **Paired full-top plan:** Run three opposite-order bounded 240-edge
  Caliptra full-top pairs, baseline versus this branch, on the campaign Mac.
  Diff stdout, execution, port and bus traces; compare median CPU over
  edges 40–240.
- **Go/stop:** Keep it if all traces are identical and the median CPU gain
  is at least 3% with no pair regressing more than 2%. If the full-top gain
  is below 1%, keep it only as a neutral cleanup and do not pursue the
  approach further.

### 2. Bounded procedural-loop specialization before VVP emission — highest remaining gain

- **Stronger soundness argument than the handoff assumed.** Adams Bridge's
  indices are declared in the for-init, so they have automatic lifetime
  (§12.7.1). They cannot be referenced hierarchically (§6.21), and this fork
  already refuses value-change callbacks on them (observation 5). With a
  body that contains no calls, timing controls, or forks, no VPI callback
  can run between iterations, so no VPI application can observe `j` during
  the loop. The loop's end lifts `j`'s lifetime. For this class of loop,
  removing the index stores is therefore exact. It is *not* just an
  upper-bound diagnostic. A loop over a static index, such as `integer k`
  or a module variable, must keep one store per iteration and the final
  value, because each store is VPI-visible.
- **Boundary:** An elaboration-time functor over `NetForLoop`, after
  elaboration and before `emit`, driven by these symbols:
  - `NetForLoop::index_`, `init_expr_`, `condition_`, `statement_` and
    `step_statement_` (`netlist.h`);
  - `NetExpr::eval_tree`, for folding;
  - the implicit-block scope created at `elaborate.cc` around line 24440.

  The pass needs a small statement cloner with signal-to-constant
  substitution for `NetBlock` (unscoped), `NetAssign`, `NetAssignNB`,
  `NetCondit` and nested `NetForLoop`. No such cloner exists today. Then
  fold constant `NetCondit`s, and constant `NetAssign_` word/base
  expressions, into constant offsets. The implicit block scope and its
  variable must stay in the scope tree, so VPI iteration still sees
  `$unm_blk_*.j`. Only the per-activation `%alloc`/`%fork` disappears.
- **Correctness conditions (reject otherwise):**
  - The index is automatic and declared in the for-init, or else stores are
    retained.
  - The init, bound and step are constant, with the step of the form
    `j = j ± c`. The trip count is computed with the index's own width and
    signedness (32-bit `int` here).
  - The trip count is at most 64 and the cloned body is at most N nodes,
    with a per-module growth cap (Verilator's defaults: `--unroll-count`
    64, `--unroll-stmts` 30000, `--unroll-limit` 16384 for
    `unroll_full`).
  - The body has:
    - no writes to the index;
    - no delay or event controls, and no `wait` or `fork`;
    - no user or system task/function calls, and no `$display`;
    - no `disable`, `break`, `continue` or `return`;
    - no force/release or procedural assign/deassign;
    - no event triggers or class/object operations;
    - no nested scoped block that declares variables.
  - NBA statements keep their textual order, so enqueue order is unchanged
    and every update event and callback on the targets is preserved.

  Verilator's `V3Unroll.cpp` rejects the same `fork`, impure-call and
  timing-control shapes. VVP's dynamic event queue is irrelevant inside a
  body with no timing control, because the body runs atomically in one
  thread activation.
- **Tests (paired 2017/2023):**
  - A2B-shaped equivalence: rolled versus specialized hash, with X injected
    on `rst_n` and data.
  - Four-state: indexes that select out of range after specialization (X
    fill), an X in data, and `j-1` at `j == i` boundaries.
  - NBA order: two NBAs to overlapping bits in one iteration, and across
    iterations; the last one must win.
  - VPI:
    - `cbValueChange` on an NBA target counts per-update callbacks, which
      must be unchanged;
    - `vpi_iterate` still finds `$unm_blk_*.j`;
    - a static-index loop gets one callback per iteration with the right
      values.
  - Negative controls, which must not specialize: a call in the body,
    `#0`, `break`, a write to `j`, a non-constant bound, and 65 iterations.
    Verify with `-pdebug` or a dump flag listing rejected loops.
- **Expected costs (inference):**
  - Code size is bounded by the caps. The handoff's full-top expansion was
    +1.63% image size and +3.5% compile time.
  - Implementation estimate: about 2–4 engineer-days. The cloner is the
    main cost.
- **Paired benchmark:** the reducer at 1,000 cycles, then the same full-top
  protocol as item 1, measured on top of item 1.
- **Go/stop:**
  - Go if the reducer is at least 1.5× faster in CPU on top of item 1, the
    full-top median CPU gain is at least 8% over three pairs, traces are
    identical, and the image grows at most 5%.
  - Stop if the full-top gain is below 3%.

### 3. Incremental propagation for partial writes to wide variables — next after item 2

- **Why:** After items 1 and 2, NBA application is about 40% of the
  reducer, and each partial NBA costs O(vector width).
- **Candidate boundaries, least invasive first:**
  - (a) Have `vvp_fun_signal4_sa::recv_vec4_pv` tell the `vvp_wire_vec4`
    filter which range changed, so the filter compares and copies only that
    range. No fanout change.
  - (b) Coalesce pending disjoint partial NBAs to the same variable within
    one NBA batch into one propagation.
- **Correctness conditions for (b):**
  - The variable has no VPI value-change callback, force or assign mask.
  - The coalesced updates cover disjoint bits, so every bit changes at most
    once and no edge on any bit is lost.
  - The change corresponds to the legal order "all update events before
    the resulting evaluation events". Section 4.5 leaves the choice of
    Active-region events unordered, and §4.6 fixes only the per-process
    order of NBA updates. That must be proved against this fork's
    event-synchronous deferral (`vvp_event_defer_callback_cone`) before any
    implementation.
- **Tests:**
  - A posedge on a derived net with a glitch (must match the legal
    ordering argument);
  - `cbValueChange` counts on the variable when a callback is present
    (must disable coalescing);
  - `always_comb` wakeups (at least one);
  - `$monitor`/`$strobe`;
  - force/release in the middle of a batch.
- **Go/stop:** Prototype (a) first. Go if it gives at least 1.15× on the
  reducer after item 2; stop (b) if (a) captures most of the gain.

### 4. Automatic-frame access fast path

- **Status:** About 12% of the rolled reducer, but item 2 removes nearly all
  of it for this workload.
- **Risk:** The scoped context lookup
  (`vthread_get_rd_context_item_scoped`) has many correctness special
  cases (callf return frames, staged `%alloc`), so a cache there carries
  moderate risk for a gain that item 2 delivers more safely.
- **Recommendation:** Defer until a workload shows automatic-variable cost
  that loop specialization does not remove.

### 5. Multicore scheduling — defer; re-certify after item 2

- **Why defer:**
  - Items 1 and 2 shrink exactly the parallelizable RHS/body work. On the
    reducer, instructions fall 2.43×.
  - The serial part is NBA application and its wide-vector propagation,
    and the proposed design keeps NBA intent replay serial. On the reducer
    after items 1 and 2, thread execution is about 56% of Ir and NBA
    application about 40%. An ideal two-worker split of the thread part,
    with zero overhead, bounds the reducer at about 1/(0.44 + 0.28) ≈ 1.39×.
    That is an inference; the full-top fraction is unknown.
- **A better batching boundary (inference):** Item 2 removes the three
  obstacles the handoff lists:
  - the implicit-block `%fork`/`%join` disappears;
  - the automatic index and its immediate stores disappear;
  - dynamic NBA offsets become constants.

  After it, each A2B/adder instance's 92 `always_ff` bodies on one
  `posedge clk` read only instance-local registers and ports and write only
  instance-local variables through constant-offset NBAs. That is a
  certifiable per-instance macro-task, of the kind Verilator's
  `V3OrderParallel.cpp` builds statically. These bodies run on every edge
  outside reset and zeroize, so they are the natural candidate for the
  existing ≥0.5 ms on ≥90/100 edges gate.
- **Correctness conditions:**
  - Workers compute RHS values only into private intent buffers, from a
    snapshot taken at the start of the Active region.
  - Replay is serial, in original process and statement order.
  - No VPI, DPI, class, randomization, system-task or blocking shared
    write occurs in a task, and there is no derived-clock feedback.
  - The global `running_thread` and trampoline state are never touched on
    a worker; workers run a specialized straight-line evaluator, not
    `vthread_run`.
- **Go/stop:** Keep the handoff's gate unchanged, but measure it after
  item 2 and on the specialized code. If fewer than 90/100 edges carry
  ≥0.5 ms of certified work, or the gain after overhead is below 5%, stop
  multicore work.

## Data needed from the campaign host (fork-specific)

- The bounded 240-edge full-top harness and trace-diff scripts, to run
  items 1 and 2 as paired full-top comparisons.
- The frozen 200-edge profile rerun with this branch, to see whether the
  68.2% adder share and the `%load/vec4` share move as the reducer did.
- For item 5: the opt-in VVP profiler output restricted to the adder
  processes after item 2, plus the serial NBA-intent log for one edge, to
  count per-instance certified work.

## Addendum (2026-09-29): common workloads and multithreading

Revision-scoped to the branch's later commits. Same Linux container; CPU
ratios are medians of three interleaved baseline/new pairs, and the
baseline is `7a04009f` `vvp` and `vvp.tgt` with the same `ivl`.

### Workloads

| Workload | What it exercises |
|---|---|
| `sha` | Caliptra v2.1.2 secworks `sha512_core` and `sha256_core`, 400 chained blocks each; named `always` blocks and wide datapaths |
| `pico` | picorv32 `testbench_ez` for 300k cycles, with its per-access `$display` replaced by a checksum; CPU-style RTL and task calls |
| `a2b` | The Adams Bridge A2B reducer above, 150 cycles |
| `uvmnone` | A UVM ALU environment (sequence, driver, monitor, scoreboard with a reference model), 200 transactions, no constraints |
| `uvm` | The same environment with a `dist` on `op` and an implication coupling `op` to the 32-bit `b` |

The UVM runs report `checked=200 errors=0`, with no UVM errors or fatals.

### Results

| Workload | Round 1 median | Round 2 median | Output |
|---|---:|---:|---|
| sha | 1.86× | 1.86× | same |
| pico | 1.35× | 1.23× | same |
| a2b | 1.55× | 1.28× | same |
| uvmnone | 1.20× | 1.22× | same |
| uvm | 0.96× | 1.03× | same |

The two rounds differ by host noise. Round 1's 0.96× on `uvm` came from
the first hash-map symbol table. Instruction counts stayed within 0.2%,
but the map made one heap allocation per symbol while the design loaded,
and the solver-heavy run then lost about 3%. The flat open-addressed
table fixed it (five interleaved runs: median 11.31 s against 12.18 s).

Compile and load, for the UVM testbench:
- Compile CPU dropped from 6.66 s to 2.87 s.
- `vvp` load instructions dropped from 10.8G to 5.1G. Load is only about
  1 s of wall time.

### Where the remaining time goes

- **Constrained randomization dominates constrained UVM.** Per
  transaction, over 200 transactions:

  | Constraints | ms/txn |
  |---|---:|
  | none | 3.6 |
  | `op < 5` | 9.0 |
  | `dist` only | 12.7 |
  | `dist` plus the implication onto a 32-bit field | 55 |

  About 171M instructions per call are in `Z3_optimize_check`, reached
  from the `bvxor` minimization used for sampling (`vvp_z3.cc`). Changing
  that is a redesign of the sampling method with probability-exactness
  obligations (AGENTS.md "Randomization invariants"). It is out of scope
  for a performance patch and ranks first for UVM workloads.
- **UVM method calls cost thread churn.** Every task and function call
  creates and deletes a thread, about 5.5K instructions each: three
  `std::deque`s, a `vvp_process` registered in a live-object `std::set`,
  and scope and registry set insertions. Automatic frames add
  `%alloc`/`%free` context-chain work. Each class-property store also
  notifies every handle that aliases the object.
- **Compile time left.** Elaboration's `dynamic_cast` chains over
  `data_type_t` and `ivl_type_s` are about 31% of the remaining compile,
  spread across dozens of type-resolution helpers.

### Multithreading findings

- **FST dumping (done):** the GTKWave FST writer's background-thread
  mode was compiled out. It is now enabled when pthreads exist.
  - Files are byte-identical in every FST mode tested.
  - The `-lxt2-speed` packing mode was already nondeterministic between
    two serial runs.
  - About 10% less wall time on a picorv32 full-signal dump. Most
    dumping cost stays on the simulation thread, in value-change
    callbacks.
- **VCD dumping:** costs about 2.8 s on a 6.2 s picorv32 run, almost all
  CPU in callbacks and formatting (0.14 s of system time). A writer
  thread would need `sys_vcd.c` to queue raw values. That is a moderate
  change for at most about half the cost; not done.
- **Compiler:** elaboration (64% of the remaining compile) mutates one
  global `Design` and specializes classes in order, and parsing is one
  include tree. Only code emission (about 21%) could be split, and
  `tgt-vvp`'s global label, register and flag allocators would all have
  to become per-thread with deterministic merging. That is a large
  change for at most about 1.2× on compile. Not recommended before the
  `dynamic_cast` work.
- **Simulation threads:** unchanged from the ranking above. The
  single-core changes shrink the parallel share first. The per-instance
  macro-task argument still stands for Adams Bridge after loop
  specialization.
