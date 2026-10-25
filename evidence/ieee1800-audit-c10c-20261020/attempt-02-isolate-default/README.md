# §10.9 assignment patterns — isolated nested-default check

Slurm job 3528 reran the positives after separating the nested-array default case, plus four negative probes, with Icarus 13.0-devel (`cc25756d1`) under `-g2017` and `-g2023`. Each compile and any subsequent run had a 30-second timeout; allocation was 1 CPU / 1 GiB. Tool hashes and raw per-case logs are in `slurm-3528.out` and `results-3528/results/`.

`p10_09_patterns` compiles and runs in both editions, producing the expected P1–P4, A1–A5 values. The control `p10_09_nested_default_controls` also passes in both editions: an outer array default fills a 2-D array, and explicit nested array patterns work inside the structure. In contrast, both statements in `p10_09_struct_default_nested_array` fail elaboration in both editions with “integer literal is not compatible with an unpacked type in this context.” This isolates the mismatch to default propagation from a structure pattern into an unpacked-array member.

Duplicate array index, uncovered members, and too few positional elements are rejected in both editions. Duplicate member keys are also rejected, but the cited §10.9.2 matching rules have no explicit repeated-member error requirement, so this is observation only pending lead review.

Input sources and hashes are preserved under `input/`. Open and closed dedupe results for the lead's requested terms are in the parent attempt's [`dedupe-results.md`](../attempt-01-patterns/dedupe-results.md). Standards excerpts and clause/page citations are in the parent's [`STANDARD.md`](../attempt-01-patterns/STANDARD.md).
