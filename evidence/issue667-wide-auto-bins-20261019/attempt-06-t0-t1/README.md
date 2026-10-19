# #667 corrected T0/T1 qualification, attempt 06

Attempt 05 built the feature branch successfully (peak RSS 1,670,156 KiB) and passed both issue-specific legacy tests (2/2). Its JSON T0 stopped on the two compile diagnostics from the exact class-property reproducer; the empty new stderr golden did not record the already-known property-resolution / constant-sample limitation. No smoke or T1 result was produced. Slurm accounting is disabled, so the scheduler exit code is unavailable; the captured runner output ends at that JSON comparison and has no end-time/result marker.

Attempt 06 adds the observed diagnostics as the stderr golden for this new regression only. It rebuilds the source snapshot, runs both T0 runners and the smoke set, then runs all `sv_covergroup_*` tests for T1 in legacy and JSON. It separately compiles the §19.5.3 non-power-of-two probe in both language editions and requires the expected `power-of-two auto_bin_max` diagnostic.

T1 selection remains every `sv_covergroup_*` case in `ivtest/regress-sv.list` and `ivtest/regress-vvp.list`, because the change touches covergroup elaboration and VVP sample-time bin matching. The exact class-property sample's hit count is not asserted; that is a separate known limitation.

Result: Slurm job 3113 completed at 10:43:27 MDT and wrote `T0/T1 PASS`.
Build/install succeeded (2:09.56 build wall time, peak RSS 1,670,656 KiB).
T0 passed 2/2 in legacy and 2/2 in JSON; `ci/run-smoke.sh` exited 0. T1
passed 298/298 legacy and 285/285 JSON tests. The audit probe failed
compilation with the expected §19.5.3 diagnostic in both `-g2017` and
`-g2023`. Captured logs are gzip-compressed for compact storage; use `gzip -cd <path>.gz` to read them. Raw result files and lists are under `remote-job-3113/`.

Clause check: §19.5.3 in both IEEE 1800-2017 and 1800-2023 specifies
uniform distribution into `N = min(2^M, auto_bin_max)` bins and explicitly
allows implementations to limit the number of automatic bins. The 65,536
implementation cap is therefore allowed; restricting wide counts to powers
of two is the tracked conformance gap.
