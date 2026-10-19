# #448 baseline reproducer

- Source revision: `ca559fd97b19bd6a56cc10f0faf8583b4077975f` (`origin/main`).
- Host: DAN-DESKTOP Slurm, job 2569, partition `verilog`, 1 CPU, 2 GiB requested.
- Toolchain: protected `/home/dsell/toolchains/iverilog-uvm-ca559fd97b19bd6a56cc10f0faf8583b4077975f-m3-profile`; Icarus SHA-256 `c99ee9c08468fb20f7635fb3380adb0d620c9037c19c02236a435a61c7be0130`, VVP SHA-256 `01ab4aec7220761157afa00b19074da9ce6f3f261279fcb39d319865a09056a4`.
- Command: for each `-g2017` and `-g2023`, compile `issue448-red.sv`, then run with `IVL_COVERAGE_REPORT=<report path>`, each under a 60-second process timeout.
- Result: both editions compiled and sampled two bins successfully, then reported only aggregate type coverage and bins. No per-instance row was emitted even though the constructor formal selected `option.per_instance = 1`; the covergroup handle was destroyed before `$finish`.

This confirms the §19.7 report-retention gap without changing any existing golden.

A second paired reducer reads each instance's `option.per_instance` value after construction. The same protected main toolchain instead emits `sorry: covergroup option members are not run-time state; this read evaluates to constant 0` in both editions; the runtime assertion for the constructor value then fails in each. This identifies the missing hidden per-instance property and constructor initialization path. See `red-2571.out`.

## Implementation boundary

- Active blocker: #448, instance-specific `per_instance` option state and report retention.
- Expected semantics: IEEE 1800-2017/2023 §19.7 says definition option assignments are evaluated at covergroup instantiation; when `per_instance` is true, that instance's coverage information is saved in the coverage database and included in the report.
- Root cause: the front end recognizes but does not retain the `per_instance` expression/property; the current report emits aggregate type counters only.
- Scope: retain the constructor-evaluated boolean, reject procedural writes, and report both live and retired instances whose captured value is true. Preserve aggregate output and avoid changing existing golds.
