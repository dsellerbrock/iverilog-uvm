# §10.10 unpacked-array concatenation — corrected probe

Slurm job 3531 tested the corrected positive and four negatives under Icarus 13.0-devel (`cc25756d1`), in both `-g2017` and `-g2023`; each compile and any run was limited to 30 seconds. The source replaces the invalid nested-unpacked-concatenation positive with the legal §10.10.3 sized-vector item (`U8`) and tests the standard's byte-array concatenation (`U7`).

The combined positive fails compilation at U8 in both editions with `A concatenation cannot be elaborated in an assignment context of type netvector_t:bool signed[31:0]`. The other positives could not run in this combined file; isolate U8 before classification. All four negatives compile-reject in both editions. Full raw logs and per-case files are in `slurm-3531.out` and `results-3531/results/`.
