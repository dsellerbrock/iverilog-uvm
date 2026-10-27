# §16.9.4 global-clock sampled-value probes — attempt 16

The run built a clean snapshot of current `origin/main` (`c31cbf1b52f1a39d5775f276e2340525a444a79e`) on DAN-DESKTOP, then tested the positive `$past_gclk` property and the missing-global-clock negative in both editions with assertions enabled.

- Slurm job: 3186; 3 CPUs, 4 GiB; completed in 2:10; build peak RSS 1,663,088 KiB.
- Build: `autoconf`, configure, `make -j3`, and install all passed.
- Icarus SHA-256: `f958f85546420cdaf3c67d73e7c377e63a55a3df9c4dca6de16955e81000b818`.
- VVP SHA-256: `b0e2b7f230be80efe2e04b28ad5a688c46f93eaad692d34bfe27895a61983be6`.
- Probe input hashes: `results/input.sha256`.

Results are identical in 2017 and 2023 modes:

- Positive property probe compiles with exit 0, but VVP exits 1: `$past_gclk()` is not defined by any module.
- Negative call without any global clocking declaration compiles with exit 0, so the required diagnostic is absent; it was not run because the positive run already demonstrated the unresolved function runtime error.

This establishes a §16.9.4 feature gap on current main. Supplemental probes for the future-function family and its normative context restrictions are in attempt 17. The two jobs together will be presented to the audit lead for classification and deduplication.
