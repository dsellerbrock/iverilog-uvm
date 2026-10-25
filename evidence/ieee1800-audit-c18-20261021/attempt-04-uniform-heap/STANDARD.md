# §18.5.10 / §18.5.9 uniform distribution

IEEE 1800-2017 §18.5.10 and IEEE 1800-2023 §18.5.9 require uniform probability over all legal value combinations. The previous attempt's flat `a<b<c` constraint did not trigger the large-component fallback, so this probe reuses the standard's Figure 18-2 heap shape that emitted the warning in Slurm job 3486.

For `0 <= l <= v < r <= 255`, each value of `v` has weight `(v+1)(255-v)`, for 2,796,160 legal triples. Uniform selection gives expected means 63.5, 127.0, and 191.5; the expected count with `v<32` is 88.5 of 2,000. The lead-provided 5σ windows are recorded in `README.md`.
