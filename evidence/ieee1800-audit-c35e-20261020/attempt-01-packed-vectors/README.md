# Clause 35 packed-vector and fixed-array ABI probe

Run the existing M10 packed-vector and fixed-array ABI regressions in both
language editions. The cases exercise packed 2-state and 4-state vectors,
including wide and scalar-width vectors, plus fixed unpacked arrays whose
elements are packed bit and logic vectors.

Standard scope: IEEE 1800-2017/2023 §35.5.5 and §35.5.6; Annex H C ABI.
The exact expected/observed output, toolchain, command results, and checksums
are recorded in `RESULT.md` after the Slurm run.

Inputs are existing, tracked tests. No test or expected output is changed.
