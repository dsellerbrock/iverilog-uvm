# §16.9.4 global-clock sampled-value probes — attempt 17

This run tested the future-function family and the clause's context boundaries against the protected compiler built from clean current `origin/main` (`c31cbf1b52f1a39d5775f276e2340525a444a79e`) in Slurm job 3186.

- Slurm job: 3187; 1 CPU, 1 GiB; completed in under a second.
- Icarus SHA-256: `f958f85546420cdaf3c67d73e7c377e63a55a3df9c4dca6de16955e81000b818`.
- VVP SHA-256: `b0e2b7f230be80efe2e04b28ad5a688c46f93eaad692d34bfe27895a61983be6`.
- Input hashes and raw compiler/runtime logs are in `results/`.

In both `-g2017` and `-g2023`:

- `$future_gclk` / `$rising_gclk` positive-property probe: compile exit 0; VVP exit 2 because both functions are undefined.
- Legal procedural `$past_gclk` probe: compile exit 0; VVP exit 1 because `$past_gclk` is undefined. This context is permitted by §16.9.4.
- `$past_gclk` with no global clocking declaration: compile exit 0; VVP exit 1 because `$past_gclk` is undefined, so the required no-global-clock diagnostic is absent.
- Illegal procedural `$future_gclk`: compile exit 0; VVP exit 1 because the function is undefined; no compile-time context diagnostic is produced.
- Nested future-function probe: compile exit 0; VVP exit 2 because `$rising_gclk` and `$future_gclk` are undefined; no compile-time nesting diagnostic is produced.

Together with attempt 16, the probes show that the global-clock sampled-value functions are not implemented in the current-main compiler. The tech-lead's proposed blanket prohibition on procedural calls was not applied: IEEE 1800-2017/2023 §16.9.4 explicitly permits the past family in general procedural code and assertion action blocks, while restricting the future family to properties/sequences, prohibiting nesting, and requiring a defined global clocking declaration.
