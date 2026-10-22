# §§16.9.5–16.9.7 sequence operators — attempt 19

The corrected discriminating probes passed on a clean current-main compiler snapshot (`c31cbf1b52f1a39d5775f276e2340525a444a79e`) under both `-g2017` and `-g2023`, with assertions enabled.

- Slurm job: 3189; 1 CPU, 1 GiB; all compile/run steps exited 0.
- Compiler: Icarus `f958f85546420cdaf3c67d73e7c377e63a55a3df9c4dca6de16955e81000b818`; VVP `b0e2b7f230be80efe2e04b28ad5a688c46f93eaad692d34bfe27895a61983be6`.
- Input hashes and raw outputs are in `results/`.

`p16_09_05_07_seq_comb.sv` verifies unequal-duration `and`, equal-duration `intersect`, and `or` with one matching operand. `p16_09_06_intersect_length_mismatch.sv` confirms that unequal fixed-length operands do not match under `intersect`. All four simulations printed `PASSED`.

Attempt 18 is retained as a harness correction record: its mismatch probe passed, while the combined positive probe incorrectly counted vacuous assertion pass actions. Attempt 19 replaces that counter with fatal failure actions and is the valid result.
