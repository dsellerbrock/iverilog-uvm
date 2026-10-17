# WP14 copy-and-patch SHA-256 ceiling spike

This is the requested speed-of-light spike on Caliptra's SHA-256 round kernel.
It is isolated in this evidence directory: no VVP runtime or default-build
file is changed, and it adds no required dependency. The hard stop is the
measurement and go/no-go below.

## Target and inputs

The hot operation is `sha256_core`'s per-round T1/T2 arithmetic and state
update (`t1_logic`, `t2_logic`, and `state_logic`). The inspected RTL is
Caliptra RTL commit `49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e`. The simulator
candidate is #601 snapshot `3b620c5ea5857ba7c022a7fba058f8a31b7ac564`, built
from measurement base `631b7a869faaa05216d8749224520227b4b23d43`; its VVP runtime
is unchanged from code commit `51987d3cccfe2ddb862eb01b9a7388eb687276c6`.
The campaign comparison base remains `f9f8e0a79f230f38da6cbb4445994ad1075ad531`.

The standalone testbench is the existing `tb_sha256.sv` SHA workload, with
`NBLK=800` (1,600 blocks, 102,400 SHA rounds). The copy-and-patch program
interprets the round using function-pointer bytecode handlers and four-state
a/b planes, then runs a native x86-64 stencil with each round's K constant
patched into its immediate. A guard sends any X/Z input back to the four-state
interpreter. The 64 stencils occupy 13,312 bytes; each unpatched stencil is 199
bytes. The prototype checks all outputs against both its interpreter and the
Caliptra RTL testbench. The timed workload leaves message scheduling and the
outer loop shared between the two paths, isolating round arithmetic and state
update.

## Profile of the full Caliptra test

Slurm job 2038 sampled `smoke_test_sha256` on one pinned CPU over the fixed
2,000-mcycle window `[100, 2100]` (elapsed 191.644 seconds). The run stopped at
that window, so the Caliptra runner marked the full firmware test incomplete;
the Slurm wrapper nevertheless captured the profile. The report contains
23,817 `task-clock:u` samples with no lost samples. Its largest listed VVP
handler was `of_LOAD_VEC4` at 14.70% inclusive. This is whole-test attribution,
not SHA-round attribution, and the recorded event is task-clock rather than
hardware cycles. See [profile/perf-report.txt.gz](profile/perf-report.txt.gz) and
the recorded run metadata in `profile/`.

## Measurement

Slurm job 2046 ran on CPU 0 of an Intel Core Ultra 9 285K. The standalone VVP
testbench and the copy-and-patch microbenchmark were run five times in
alternating order. Each microbenchmark sample timed 100 complete workloads;
the table reports the median per-workload time across five outer runs and the
min-to-max spread relative to that median. The native kernel passed the
zero-relocation check and the injected X/Z guard fell back to the interpreter.

| Path | Median per 1,600-block workload | Spread |
|---|---:|---:|
| Four-state bytecode round interpreter | 4.571 ms | 0.109% |
| Copy-and-patch native round kernel | 0.913 ms | 0.836% |
| Kernel speedup | 5.008× | 0.921% |
| Full VVP RTL testbench (context only) | 0.980 s | 2.041% |

All five VVP testbench runs and all copy-and-patch runs produced
`sha256=f14ea99f sum=6541416fc3f26974`, matching the RTL output. Runtime
copy-and-patch setup took about 20 microseconds for the 64 stencils. Raw
outputs, timings, hashes, stencil bytes, and disassembly are in `results/`,
`build/stencil.bin`, and `evidence-bundle.tgz`.

## Go/no-go

The measured kernel-only ceiling is about 5.0× over this small four-state
bytecode round interpreter. It is **not** a measured VVP speedup: the prototype
does not execute through VVP's scheduler, signal propagation, or real VVP
bytecode, and the full-test profile does not isolate the SHA kernel. **No-go
for expanding WP14 or integrating this prototype on the current evidence.**
This completes the authorized spike; going further requires a new user
instruction.

## Attempts

- Job 2036 stopped during source-revision preflight and produced no samples.
- Job 2038 captured the bounded full-test profile described above.
- Job 2040 exposed that the testbench's first message block is zero because
  the digest output is still reset; that input was corrected.
- Job 2041 matched the RTL digest, but its sub-millisecond timed samples had
  23.8% spread. The final measurement lengthened each sample to 100 workloads.
