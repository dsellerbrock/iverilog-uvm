# §10.10 unpacked-array concatenation — initial probe

Slurm job 3530 tested the first positive probe and four negatives under Icarus 13.0-devel (`cc25756d1`) with both language editions. The positive source included a nested string concatenation item modeled on the legal §10.10.3 example; it failed compilation at line 9 (`this expression (kind 18) cannot be evaluated in a vector context`). Because the combined positive stopped there, no U1–U4 output was produced. The later corrected run separates the standard's sized-vector example and main queue/array behavior.

The four negatives compiled as errors: a fixed-size element-count mismatch, a context-free concatenation, a nested unpacked-array concatenation, and an array-valued item in an assignment pattern. Full logs and raw per-case outputs are in `slurm-3530.out` and `results-3530/results/`. Input sources and hashes are under `input/`.
