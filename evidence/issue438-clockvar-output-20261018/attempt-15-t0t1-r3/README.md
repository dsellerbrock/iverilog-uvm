# #438 T0/T1 validation, retry 3

- PR: #669, branch `agent/a3-m7-issue438-clockvar-output-20261018`
- Tested source commit: `79c20c387f9f7f267049a9154710d3395b5bef6d`
- Current PR head: `3feb2a60acef33b305672b1e8b238ef72231ddb1`; the only later change removes two unreferenced failure golds.
- Main base: `cae035642e056644274a01e98d4422ce286685b4`
- Red evidence: T2 batch-2b reported an extra early procedural-assignment diagnostic for `sv_clocking_output_continuous_alias_overlap`; the existing expected diagnostic comes from the deferred driver check.
- Fix: only elaborate selected, non-coerced declaration targets for the sampler target shape; use the raw signal for unselected aliases and coerced-to-uwire storage.
- T0 covers 11 legacy and 12 JSON issue cases, including the alias-overlap diagnostic in both language editions, plus the smoke set.
- T1 reruns the focused clocking legacy and JSON lists, adding the alias-overlap case in both editions; its logs record the exact runner totals.
- PR commit `edbae7302` already replaced the former #437 failure stub with positive paired 2017/2023 VIF selected-target regressions. T0/T1 include those tests; this PR update removes the two now-unreferenced failure golds.
- Slurm request: 3 CPUs, 8 GiB RAM, 2.5 hours; configure/build/self-check/install, T0 and T1 use one isolated run directory and the read-only shared UVM toolchain.
- Source archive SHA-256: `6f37727135e8205948491365b646d5df424e4715dd5f6453ea1c6331c8795d7d`.
- Slurm job 3050 completed with exit 0. T0: 11/11 legacy, 12/12 JSON, and smoke 133/133 passed. T1: 50/50 legacy and all 57 JSON cases passed. Both editions of `sv_clocking_output_continuous_alias_overlap` passed the expected compile-error check.
- Compiler SHA-256: `iverilog` `10800e7f1928d1cea159c407b8e4aa098d4ef2551033c1f7958e88f5eb599ba1`; `vvp` `8257886d60b0da2d6d076ba6c50334a062a34f36f6805d3a78ca8621095fb9d1`.
- Raw job logs and results are preserved under `remote-job-3050/`. GitHub Fast Linux on the current PR head is pending.
