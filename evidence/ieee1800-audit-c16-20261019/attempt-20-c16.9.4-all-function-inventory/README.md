# §16.9.4 all-function inventory — attempt 20

This inventory test was designed to prove that all ten names are unresolved in both editions. Slurm job 3190 compiled the source in `-g2017` mode (compile exit 0), and VVP reported seven undefined functions before the runner's assertion that every name must fail stopped the job. The log did not report `$rose_gclk`, `$fell_gclk`, or `$stable_gclk` as undefined. This disproves the all-ten-missing assumption but does not by itself prove those three functions work; their values are checked directly in attempt 21.

- Source: clean current main `c31cbf1b52f1a39d5775f276e2340525a444a79e`.
- Icarus: `f958f85546420cdaf3c67d73e7c377e63a55a3df9c4dca6de16955e81000b818`; VVP: `b0e2b7f230be80efe2e04b28ad5a688c46f93eaad692d34bfe27895a61983be6`.
- The test did not run under 2023 mode because its overbroad missing-function assertion stopped after the 2017 log.
- Raw files are in `results/`.
