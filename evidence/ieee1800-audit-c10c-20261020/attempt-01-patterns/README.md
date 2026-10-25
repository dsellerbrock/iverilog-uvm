# §10.9 assignment patterns — first pass

Slurm job 3527 ran the original positive probe and four negative probes under Icarus 13.0-devel (`cc25756d1`), with `-g2017` and `-g2023`. Each compile and any subsequent run had a 30-second timeout; allocation was 1 CPU / 1 GiB. Compiler and VVP hashes are recorded in `slurm-3527.out`.

The first positive file included two additional nested-array-default cases. They failed compilation at both editions (two errors: “integer literal is not compatible with an unpacked type”), which prevented this combined positive file from running. The later isolated attempt splits those cases and retains the remainder of the positive probe.

All four negatives rejected at compile time in both editions. Duplicate array index, uncovered members, and too few positional array elements have direct §10.9 requirements. Duplicate struct member key is recorded as an observation only pending the lead's interpretation; the cited §10.9.2 text does not expressly require a diagnostic for a repeated member key.

Raw per-case compiler/runtime files are in `results-3527/results/`; the complete Slurm transcript is `slurm-3527.out`. Input sources and hashes are preserved under `input/`.
