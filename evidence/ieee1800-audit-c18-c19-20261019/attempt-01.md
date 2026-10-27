# Audit probe attempt 1 — harness configuration error

- Slurm job 2894 on DAN-DESKTOP, 1 CPU / 2 GiB, exit `1:0`, elapsed 2 seconds.
- The §18.12 positive probe passed in both `-g2017` and `-g2023`, printing `PASS scope randomize clause 18.12`.
- The focused §19 JSON tests failed to compile because `vvp_reg.py` found the system Icarus 12 on `PATH`, not the pinned Icarus 13 built for the feature run. The failure is a runner-path error, not a simulator result. The retry exports `PATH`, `IVERILOG`, and `VVP` for the pinned build.
- The initial no-argument probe only compiled and did not exercise the checker result. It has been corrected to assert satisfied and unsatisfied outcomes before retrying.
- Raw output: `audit-probes-attempt-01.tar.gz`.
