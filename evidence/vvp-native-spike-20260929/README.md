# Native-code feasibility spike for VVP process bodies (2026-09-29)

This is a feasibility spike, not a merged feature. `runtime.diff` is not
applied to any branch. It is the evidence for the "native-code backend"
option in `docs/conformance/session_logs/2026-09-28_vvp_single_core_multicore_assessment.md`.

## Question

How much of `vvp`'s simulation time goes away if process bodies run as
compiled machine code instead of through the bytecode interpreter? The
scheduler, nets, events and VPI stay as they are. Can that be done
without giving up 4-state semantics, the event regions or the order of
side effects?

## Method

- `native_gen4.py in.vvp out.vvp out.cc` translates every always-block
  thread of the form `T_n ; %wait E; <body> %jmp T_n;` into a C++
  function.
  - Every stack value of at most 64 bits is a pair of a/b bit-plane words
    in `vvp_vector4_t`'s own encoding.
  - Each operation reproduces its handler's x/z rules word-wide:
    `%and`, `%or`, `%xor` and the negated forms, `%add`/`%sub`/`%mul`
    (x/z gives all x), the compares with their eq/eeq/lt flag rules,
    reductions, pad, concat, split, replicate, shifts, `%blend`, the flag
    operations and forward jumps.
- Side effects run in program order through vvp itself:
  - loads read the signal filter's value;
  - `%store/vec4` and `%assign/vec4` (and the array and offset forms)
    push the value and run the instruction's handler;
  - a whole-net store from a thread with no automatic context calls
    `vvp_send_vec4` directly, which is the handler's own final step.
- Deoptimization: at an instruction it does not translate (a task
  `%fork`, `%alloc`, a value wider than 64 bits, a backward jump, an
  unknown opcode), the function pushes its stack and flags into the
  thread and returns that instruction. The interpreter resumes there, so
  the run stays exact.
- `runtime.diff` (against `096ad22f`) adds the experimental `%native`
  opcode and the helper interface, loads the generated library from
  `VVP_NATIVE_SO`, and runs native code only for a thread with no
  static-call or randomize overlay. Two debug aids are included:
  `VVP_NATIVE_STATS` (run and deopt counts) and `VVP_NATIVE_RANGE`
  (bisection).

## Correctness evidence

- **Workloads.** Output is identical to the interpreter on:
  - `tb_sha256.sv`: Caliptra `sha256_core`, 800 blocks;
  - `sha`: `sha512_core` plus `sha256_core`;
  - `pico`: picorv32, 300k cycles;
  - `a2b`: Adams Bridge A2B.

  The workloads are the ones in `evidence/vvp-hotpath-perf-20260928/`.
- **Differential sweep** (`sweep_one.sh`, results in `sweep_results.txt`).
  Every `normal`-type JSON ivtest program was compiled once and run by the
  interpreter and by the native translation, and stdout, stderr and exit
  status were compared.
  - 2547 programs in total.
  - 188 had translatable threads; all 188 were identical, and native code
    ran in 179 of them.
  - The other 2359 have no always-block thread of the handled form (most
    are `initial`-only).
- **Bugs found while building the spike, both fixed in the spike:**
  - `vvp_vector4_t` does not keep the inline-word bits above `size()` at
    zero, so native reads must mask to the size.
  - The debug counter arrays were too small for 557 functions.

## Results

Single runs, user CPU seconds, same host and bytecode, interpreter vs
native:

| Workload | Threads native | Interpreter | Native | Speedup |
|---|---:|---:|---:|---:|
| tb_sha256 | 12/12 | 1.91 | 0.96 | 2.0× |
| sha (512+256) | 25/25 | 3.49 | 1.63 | 2.1× |
| pico | 62/62 | 5.90 | 4.29 | 1.38× |
| a2b | 557/741 | 5.71 | 5.44 | 1.05× |

`tb_sha256` instruction counts: 20.35G interpreted, 12.19G with a first
2-state version of the native path (1.67×).

## Findings

1. **The interpreter is only part of the cost.** With every SHA process
   native, the rest is net propagation (`send_vec4`, signal filters),
   edge detection, event and thread wakeups, and vector allocation.
   Native process bodies alone give about 2× at most on RTL.
2. **Native values must be 4-state.** A first 2-state version (defined
   words only, deoptimizing on x/z) was exact but kept handing
   picorv32's main thread back to the interpreter. `'bx` defaults
   (`alu_out_0 = 'bx`) and masked x data flow through ordinary datapaths.
   The a/b-plane representation removed those hand-overs at a modest
   cost.
3. **Coverage limits.**
   - Task calls (`%fork`/`%join`) need a native call mechanism;
     picorv32's `empty_statement` task causes most of its remaining
     hand-overs.
   - Adams Bridge spends its time in automatic functions, wide (> 64 bit)
     values and continuous assignments, which this path does not touch.
4. **Next gain.** A larger gain than about 2× needs the net and scheduler
   side compiled too: static scheduling of synchronous logic,
   activity-based skipping, and native net propagation. That is the
   ESSENT/Verilator direction, and a much larger program than process
   bodies.

## Files

| File | Content |
|---|---|
| `native_gen4.py` | the translator (4-state) |
| `runtime.diff` | the experimental `%native` opcode and helper interface |
| `tb_sha256.sv` | the SHA-256 workload testbench (needs Caliptra v2.1.2 `sha256_core`) |
| `sweep_one.sh` | one differential-sweep step |
| `sweep_results.txt` | per-program sweep results |
