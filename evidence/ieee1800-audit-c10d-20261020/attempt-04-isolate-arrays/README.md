# §10.10 unpacked-array concatenation — isolated array/vector items

Slurm job 3533 ran 7 positive/control modules and 4 negatives under Icarus 13.0-devel (`cc25756d1`), with `-g2017` and `-g2023`; each compile/run was limited to 30 seconds (1 CPU / 1 GiB).

The main positive passes in both editions: U1 `1 2 3`, U2 `5 9 8`, U4 `0`, U6 `2 c`, U7 `06 0f`. A queue item alone passes (`Q 2 7 8`), and the legal nested string-concatenation item passes (`SQ 4 S1 element 0 element 3 is S2`). The vector-concatenation control passes (`V 258`).

Two positive forms fail in both editions. A fixed unpacked-array item alone (`C = {A}`) fails at compile time with `this expression (kind 18) cannot be evaluated in a vector context`; mixing a queue and fixed array in `{B,A}` fails the same way. An inner sized vector-concatenation item (`C = {{8'h01,8'h02},3}`) fails with `A concatenation cannot be elaborated in an assignment context of type netvector_t:bool signed[31:0]`. The direct controls pass, isolating both failures to unpacked-array-concatenation item handling.

The fixed-size mismatch, context-free concatenation, nested unpacked concatenation, and assignment-pattern array-valued item negatives all compile-reject in both editions. Raw transcripts are `slurm-3533.out` and `results-3533/results/`. The issue dedupe is in the parent attempt's [`dedupe-results.md`](../attempt-01-uconcat/dedupe-results.md); standards citations and the U5 correction are in [`STANDARD.md`](../attempt-01-uconcat/STANDARD.md).
