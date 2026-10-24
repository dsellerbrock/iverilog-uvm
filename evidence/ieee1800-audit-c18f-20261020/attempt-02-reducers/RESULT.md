# §18.5.9–§18.5.10 reducer results

**Host:** DAN-DESKTOP Slurm, job 3393, 2026-10-20. **Input base:** `cc25756d187314742d347267c2a513b3e640a7fb`. **Compiler:** Icarus Verilog 13.0-devel (`cc25756d1`); compiler SHA-256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`; `vvp` SHA-256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`. Each compile/runtime process had a 30-second timeout. The job left `squeue`; accounting is disabled and `seff` is unavailable, so scheduler exit metadata, elapsed time, and peak RSS were unavailable. Per-process return codes and complete logs are preserved here.

The §18.5.10 (2017) / §18.5.9 (2023) standard `s -> d == 0` check passed all 3 assertions in both editions. Across 400 randomizations, `s==1` occurred 0 times without ordering and 197 times with `solve s before d`, matching the standard's distribution example.

The corrected real-valued-order probe distinguishes editions: 2017 compilation rejects `rand real` under §18.4, while 2023 compilation and runtime pass a bounded real `solve a before b` case under §18.5.9.

The minimal static-constraint reducer isolates an implementation gap in both editions. Initially, the static constraint is active (randomizing `x == 7` against `x == 5` returns 0). After `a.c.constraint_mode(0)`, `a` reports mode 0 but `b` still reports 1 and `b.randomize() with {x == 7;}` returns 0. Re-enabling through `b` leaves `a` at mode 0; randomizing `a` with `x == 7` then returns 1. This conflicts with 2017 §18.5.11 p.520 / 2023 §18.5.10, which require the mode change to affect all instances.

Two active invalid ordering forms also pass in both editions. A `solve` target that is not `rand` compiles and randomizes successfully despite 2017 §18.5.10 / 2023 §18.5.9 restricting targets to random variables. A cyclic ordering compiles with `Warning: cyclic solve...before ordering; directive ignored` and randomizes successfully despite the clauses requiring no circular dependency. The lead will decide whether the warning is sufficient handling and whether #12 covers these ordering-validation results.

Control negatives are rejected as expected: `randc` solve-before and mismatched `static` qualification on an external constraint prototype/definition. Raw source, TSVs, compiler/source hashes, Slurm output, and all per-test logs are in this directory.

Attempt 1 is preserved separately. It exposed two probe defects: the `solve non-rand` and cycle forms were not activated by a randomize call, and the 2023 real-order domain was unbounded. The first order/static job was accidentally submitted twice (3391 and 3392); their stdout is retained, and attempt 2 is the isolated, corrected evidence.

## Open/closed issue dedupe for #831 (2026-10-20)

Searched all repository issues in both states for `static constraint`, `constraint static`, and `constraint_mode`. Closed #8 is a broad earlier `constraint_mode()` implementation item; it does not specify or demonstrate the §18.5.11 requirement that a static constraint's mode be shared across all class instances. The other text match, #617, concerns object RNG state during shallow copy. No existing issue covers the cross-instance static-mode behavior reproduced above.

## Open/closed issue dedupe for #832 (2026-10-20)

Searched all repository issues in both states for `solve before`, `before solve`, and circular ordering. Closed #12 is a broad randomization-completeness item that included basic `solve...before`; it does not cover rejection of non-`rand` targets or circular orderings. Closed #491 concerns preserving a legal selected queue-element target, and closed #494 concerns queue-size arguments to constraint functions. Neither covers validation of these illegal ordering forms. No existing issue covers the two cases reproduced above.
