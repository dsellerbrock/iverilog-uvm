# #667 T0/T1 attempt 3 — smoke-prefix setup failure

Slurm job 3111 completed configure, build, install, and the paired issue
regressions: legacy 2/2 and JSON 2/2, including 2017 and 2023. The smoke gate
then failed because this harness installed under `$RUN_DIR/install`, while
`ci/run-smoke.sh` expects `$SOURCE/local-install`; numerous checks could not
find `iverilog` or `iverilog-vpi`. This is a harness path error, not a code
result. The log's `struct_array_member_open_array_io` diagnostic is expected:
`ci/run-repros.sh` checks for that §7.6 error and prints `PASS #544`. T1 did
not run. Full outputs and `scontrol` status are in
`remote-job-3111/`.

The requested #544 smoke reclassification is already present on `origin/main`;
I verified its expected-diagnostic branch in `ci/run-repros.sh`, so no duplicate
smoke change is needed in this PR.

The next run uses the repository's `local-install` prefix, includes the exact
class-property compile reproducer alongside the formal-sample bin-routing
check, and records the non-power-of-two §19.5.3 audit probe separately.
