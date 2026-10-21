# §18.14.1 initialization RNG probe

Probe source used: `input/p18_14_initialization_rng.sv`.

The 2017 and 2023 texts say each module instance has an initialization RNG and
static processes draw seeds from it. Appending a static process must preserve
the earlier process streams when their creation and random-call order stays the
same (IEEE 1800-2017 §18.14.1, pp. 540–541; IEEE 1800-2023 §18.14.1,
pp. 561–562).

The first probe compared separate module instances with different numbers of
static processes. It failed in `-g2017`, but the comparison was inconclusive:
those instances have separate initialization RNGs, so the test did not isolate
the effect of appending a process. Raw inputs and output are retained here.

Probe SHA-256: `f3eff229f0c7b0451df1809e23d57939b1b6b62f31cf568b6358474265019082`.

Slurm job `3573` on `DAN-DESKTOP` compiled and ran only `-g2017`; its output was
`FATAL ... adding a later static process changed prior RNG streams`. The
comparison was across separate module instances and is inconclusive, so no
conformance result is claimed. Job logs and result are retained here.

The corrected probe compares the same top-level module in two builds, with a
fixed Icarus seed and replay controls, in `attempt-02-same-instance/`.
