# #438 corrected-head T0/T1 result

- PR: #669, `agent/a3-m7-issue438-clockvar-output-20261018`.
- Tested source: `79c20c387f9f7f267049a9154710d3395b5bef6d`; current PR head: `3feb2a60acef33b305672b1e8b238ef72231ddb1`. The later commit only removes two unreferenced obsolete gold files.
- Main base: `cae035642e056644274a01e98d4422ce286685b4`.
- Host: DAN-DESKTOP, Slurm job 3050, exit 0, 2026-10-19 04:20:46–04:23:52 local (3:06). Request: 3 CPUs, 8 GiB.
- Source archive SHA-256: `6f37727135e8205948491365b646d5df424e4715dd5f6453ea1c6331c8795d7d`.
- Installed `iverilog` SHA-256: `10800e7f1928d1cea159c407b8e4aa098d4ef2551033c1f7958e88f5eb599ba1`; `vvp`: `8257886d60b0da2d6d076ba6c50334a062a34f36f6805d3a78ca8621095fb9d1`.

## Results

- Build, install, and `make check`: passed.
- T0: issue-focused legacy 11/11; JSON 12/12; smoke VVP 56/56, VPI 133/133, and negative checks 152/152.
- T1: focused clocking legacy 50/50 and JSON 57/57.
- Both 2017 and 2023 `sv_clocking_output_continuous_alias_overlap` expected compile-error checks passed after removing the duplicate early diagnostic.
- The former #437 `sv_vif_clocking_output_target_select_fail` is covered by paired positive 2017/2023 selected-target runtime tests in this PR.

The raw job log, runner selections, per-case JSON results, and focused logs are retained beside this file. The changed PR head only removes unreferenced gold files; the tested source and registered tests match the current head.
