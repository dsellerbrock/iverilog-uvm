# Initial Clause 32 SDF probe results

- Slurm job 3706 on DAN-DESKTOP; 1 CPU, 1 GiB; source/toolchain base `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`.
- Icarus SHA-256 `9760f8c1ab8ad03d64761b257db74ff07603a15c4d44d2bcdba75073f006911c`; VVP SHA-256 `7fa3224c44e69b555fa86c1e3e048fa2709780276c6417ff8b7a7f0d63241c02`.
- Both editions compiled and ran each case. All captured logs had zero `SDF ERROR` occurrences. Final `squeue` check no longer showed job 3706; Slurm accounting is disabled on this host.

Observations in both editions:

- SDF `(TIMINGCHECK (SETUP ...))` prints `SDF WARNING: ... TIMINGCHECK not supported.`; no setup violation occurs, while the unannotated control also has none.
- `MINIMUM`, `TYPICAL`, and `MAXIMUM` arguments each print `$sdf_annotate currently only uses the first two argument.`; post-stimulus delays are identical for every selection: rise 2 ns, fall 5 ns.
- The `scale_factors`/`scale_type` case prints the same first-two-arguments warning and retains the unscaled 2 ns / 5 ns delays.
- The `INTERCONNECT` case has no SDF warning and reports `Y 13 1` after a transition at t10, matching the expected 3 ns delay.

The initial shell harness compared complete stdout, so `$finish` and warning chatter made its expected-output checks unreliable. `FINAL_STATUS=1` therefore is not a clean suite result. Attempt 04 normalizes to post-stimulus signal lines and reruns the checks. Raw logs remain under [`raw-slurm/logs/`](raw-slurm/logs/).
