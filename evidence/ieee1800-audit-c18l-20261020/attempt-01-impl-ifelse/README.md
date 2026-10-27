# IEEE 1800 implication and if–else constraints

- Standards checked directly in the IEEE PDFs: 1800-2017 §§18.5.6–18.5.7 (pp. 514–515) and 1800-2023 §§18.5.5–18.5.6 (pp. 535–536). Both editions permit integral predicates. The 2023 text also permits real predicates; the 2017 text says integral predicates only.
- The integral probe covers implication to one expression and a constraint set, inline bidirectional solving, if/else chains and constraint sets, and dangling-else binding. It is tested under both editions.
- Lead-directed edition split cases use a state-real predicate and a rand-real predicate with interval bounds under 2023. The state-real predicate is also compiled in both modes as the edition-gating control; 2017 must reject the real predicate.
- Inputs and the process-group timeout wrapper are under `input/`; hashes are in `input/SHA256SUMS-input.txt`. The Slurm script applies a 30-second timeout to each compiler and simulator process.
- Open+closed issue dedupe is in `dedupe-open-closed.txt`; the full 347-issue inventory snapshot is retained alongside it. #417, #463 and #840 were inspected as possible overlaps.
- Slurm run details and observed results will be added to `RESULT.md` after the job completes.
