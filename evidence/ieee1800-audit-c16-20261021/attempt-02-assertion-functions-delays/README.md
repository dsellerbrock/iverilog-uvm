# Clause 16.6/16.7 depth probes

Lead-selected paired probes for IEEE 1800-2017/2023 §§16.6 and 16.7. Cases B1/B2 test X/Z assertion truth; NB1–NB5 test prohibited references and function arguments (including the 2017/2023 `inout` delta); Q1–Q8 test cycle-delay semantics; NQ1/NQ2 test required delay diagnostics. The same clock/data setup is included in each source. Assertions use fail-only actions to keep output readable.

Results, exact commands, hashes, scheduler metadata, and final status matrix classification will be added after Slurm job completion. Open/closed issue search is recorded in `DEDUPE.md` with its 416-issue snapshot.

Slurm job 3754 completed paired 2017/2023 runs. B1/B2 and Q1–Q8 matched their expectations. NB1–NB3 were accepted despite the standard's restrictions (NB2/NB3 warn and read operands live; NB1 emits an error-like l-value diagnostic at rc 0 and fails every tick); the lead filed #913 and #914. NB4 ref arguments reject; NB5 inout arguments also reject, conforming in 2017 because copy-back has a side effect and in 2023 because it is explicitly listed. NQ1's reversed range aborts the compiler (`std::length_error`, rc 134); the lead filed #915. NQ2 rejects a variable delay with an explicit diagnostic and rc 1. Full details and per-case results: [`RESULT.md`](RESULT.md).
