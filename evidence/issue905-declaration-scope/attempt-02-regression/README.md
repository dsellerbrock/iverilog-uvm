# #905 regression attempt 02 (failed T0/T1)

- Slurm job 3844; 3 CPUs, 6 GiB; source commit `4ad8d298e`.
- Source archive SHA-256: `854b630a467e8c422511fdb0d091bca2cfb020e7f90348bb1bd2f849618eb416`.
- Build, `make check`, install, four #905 T0 cases, and the smoke set passed. T0/T1 overall failed (`T0_T1_STATUS=1`).
- T1's class defaulted-method regression failed to compile in both editions: direct parent-scope elaboration could not resolve class members (`value`, `current_state`).
- The class method default receiver probe produced four assertion `ERROR` diagnostics at lines 28-31, then printed its PASS marker. The old wrapper checked only the marker and incorrectly reported the step as passed; the probe has since been changed to `$fatal` checks and integrated in both editions.
- Legacy 2023 cases also lacked test-ID-named source wrappers. These wrappers are added in the next attempt.
- Full stdout, status, runner, receiver logs, and parenless compile diagnostics are preserved alongside this file. Matching checksums are in `sha256sums.txt`.
