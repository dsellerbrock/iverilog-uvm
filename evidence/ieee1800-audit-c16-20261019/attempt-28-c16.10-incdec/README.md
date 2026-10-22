# IEEE 1800 §16.10 increment match-item follow-up

The §16.10 inc/dec probe from Slurm job 3197 used `cover property`, which could confound the match-item result with cover-property handling. The source now uses an assertion implication while retaining the post-increment match item. This follow-up isolates that syntax and runtime effect; it must be treated as separate evidence from job 3197.

- Slurm job: `3198` on `DAN-DESKTOP`, 2026-10-19 15:42 MDT; request was 1 CPU, 1 GiB, 5 minutes. Start and finish were recorded in the same second; `squeue` was empty after completion.
- Toolchain: Icarus from main `c31cbf1b52f1a39d5775f276e2340525a444a79e`; hashes are in `results/sha256.txt`.
- The assertion implication still failed to parse at the post-increment match item (compile exit 3 in both `-g2017` and `-g2023`); no runtime occurred. Raw compiler output and batch metadata are in `results/` and `logs/`.
- IEEE 1800-2017 §16.10 pp. 413–414 and IEEE 1800-2023 §16.10 pp. 432–433 list `inc_or_dec_expression` as a `sequence_match_item`.
