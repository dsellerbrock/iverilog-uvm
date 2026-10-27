# Final T0/T1 gate — #1688 / issue #689

- Slurm job: 5018 on DAN-DESKTOP, 3 CPUs, `--mem=4G`.
- Source snapshot: `c70408e56ba4041d5042d50de2c1bd6a636b0db4` (git archive from staged feature tree on branch `agent/a3-m9-issue689-goal-comment-20261025`).
- Command: `bash evidence/m9-1688-focused-20261027/run-t0t1-final.sh`, which ran `autoconf.sh`, configure, `make -j3`, install, T0 focus, smoke and T1.
- Result: exit 0; elapsed 3:25.66; peak RSS 1,758,116 KiB.
- T0: 10/10 legacy, 10/10 JSON, smoke passed.
- T1 graph selection: 312/312 legacy and 312/312 JSON covergroup regressions passed, including both new slot tests and the existing `-g2017` rejection.
- The separate `tests/1800_audit/c19/p19_04_1_extends_2023.sv` compile failure is the same DD-145 diagnostic on exact `origin/main` 02ff255 and this branch; it is not claimed as fixed.
- Full logs and test lists are beside this file. The remote run directory was removed after fetch.
