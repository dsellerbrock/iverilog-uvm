# §16.9.5–§16.9.7 sequence operators — attempt 18

The unequal-length `intersect` probe passed in both editions. The combined positive test did not produce valid evidence: it used assertion pass actions as counters, which also execute for vacuous successes. The test therefore printed counts of 11 and called `$finish(1)`; Icarus nevertheless returned simulator exit 0. That harness result is excluded. The positive probe is corrected in attempt 19 to use fatal failure actions and explicit nonvacuous start pulses.

- Slurm job: 3188; 1 CPU, 1 GiB; current-main source `c31cbf1b52f1a39d5775f276e2340525a444a79e`.
- Compiler binaries: Icarus `f958f85546420cdaf3c67d73e7c377e63a55a3df9c4dca6de16955e81000b818`; VVP `b0e2b7f230be80efe2e04b28ad5a688c46f93eaad692d34bfe27895a61983be6`.
- Raw outputs and input hashes are in `results/`.
- The separate unequal-length intersect probe printed `PASSED` in both `-g2017` and `-g2023`.
