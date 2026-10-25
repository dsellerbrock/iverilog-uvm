# IEEE 1800 §19.11.2 cross coverage probe, retry 2

- Standard: IEEE 1800-2017 §19.11.2, p. 588; IEEE 1800-2023 §19.11.2, p. 616. The formula and zero-denominator rules match in both editions.
- Positive probe checks automatic cross bins, a merged user bin (`Bc = 2`, `Bu = 1`), zero-weight coverage, and specified zero-denominator return values.
- Boundary probe records whether a cross item accepts the two-argument `get_inst_coverage` overload.
- Toolchain: pinned main `cae035642e056644274a01e98d4422ce286685b4`, read-only at `/home/dsell/toolchains/iverilog-uvm-m18-main-cae035642e056644274a01e98d4422ce286685b4/bin`.
- Slurm request: 1 CPU / 2 GiB, 20 minutes; each compile and run has a 90-second timeout.
- First attempt (job 3054) ran the probes but its shell harness had a malformed `[ ... || ... ]` conditional, and its compile logs included static-initialization warnings. Those results are preserved under attempt 19 but do not count as clean evidence. The probe now uses explicit initialization and the harness conditional is corrected.
- Completed on DAN-DESKTOP in Slurm job `3060` at 2026-10-19 04:31 MDT; batch script and results are preserved under [`remote-job-3060/`](remote-job-3060/).
- Pinned source: `cae035642e056644274a01e98d4422ce286685b4`. `iverilog` SHA-256 `6f64b9987e04069dde9904cd1f0790d3430e34dbebb7908db159e6ec5290e330`; `vvp` SHA-256 `979d745f46bf952c86b1f09255e2256a6eec2bbef15b5c11634c8b4c95013309`.
- Positive source SHA-256 `429a71ef05e8e9d5b8e69adb44610a1b1204355d815366ec718262bb23cb71fc`; 2017 and 2023 compile/run exits were all 0. Both logs pass the automatic and user-bin cross calculations, zero-weight calculation, zero-denominator 0.0/100.0 returns, and final clause check.
- Boundary source SHA-256 `ca19eaee0f715726d78b534945126a30832e4bf5e0bc218b8dd012d1da1604ec`; both editions reject the two-argument cross `get_inst_coverage` call with `Enable of unknown task g.x_ab.get_inst_coverage`. These are the expected negative-probe exits; the overall audit script exited 0.
- No warnings were emitted by either positive compile. The exact compile/run logs, exit files, inputs, and harness are retained under `remote-job-3060/`.
- Slurm reported `RunTime=00:00:01` and `ExitCode=0:0`; accounting storage is disabled on DAN-DESKTOP, so peak RSS is unavailable. Each compile/run had a 90-second timeout.
- Audit classification and issue mapping for the missing two-argument cross overload are pending the 1800-audit lead response. Existing #622 covers missing two-argument instance count outputs; whether it covers cross items remains to be checked. #626 is specifically about `set_inst_name()` and is unrelated.
