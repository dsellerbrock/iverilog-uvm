# Issue #825 — interface signals as specify-path terminals

**Standard:** IEEE 1800-2017/2023 §25.6 and Annex A A.7.3. The tested subset accepts a simple specify path whose terminal is one vectorable member of a scalar interface port, subject to the direction exposed by that port’s modport. Ref ports are rejected.

**Scope limits:** Interface arrays, named-expression modport members, unpacked or nonvectorable members, select syntax, data-source terminals, and specify timing behavior are not covered. The no-modport test is retained, but its default path direction is not claimed as conforming pending review of §25.3.2. An unbound root interface port currently drops the path.

## Validation

- Slurm job 5272: build and T0; 56/56 smoke tests and 155/155 VPI tests passed, along with the recorded reproducer, negative, and runtime checks. The captured output is in [`validation/t0-t1/`](validation/t0-t1/).
- Slurm job 5273: typed and generic interface formals plus interface-port forwarding were probed under `-g2017` and `-g2023`; positive forward-chain probes printed `PASSED`, and reversed directions produced the expected errors.
- Slurm job 5276: final focused suite passed 43 legacy and 65 JSON cases with zero failures. The result is in [`summary.txt`](step2/attempt-9/summary.txt) and [`results.txt`](step2/attempt-9/results.txt); the tested selections are [`legacy.list`](step2/attempt-9/legacy.list) and [`json.list`](step2/attempt-9/json.list).
- The review bundle and SHA-256 manifest are in [`validation/techlead-review/`](validation/techlead-review/); focused-test lists and the manifest are in [`validation/t0-t1/`](validation/t0-t1/).

## Reproduction context

The candidate toolchain was built at `/home/dsell/toolchains/iverilog-uvm-a3-issue825-43c38efea13a94e7e831e24d2016810b46c19b00` from source snapshot `43c38efea13a94e7e831e24d2016810b46c19b00` (based on main `92c4466063ab8853a90728ec0d92dd3936c815a1`). It reported Icarus Verilog 13.0 devel. `bin/iverilog` SHA-256: `6d5b8f8dabeefff7f8e68a868b978342bdaa9d7f0444f0a74eb50705f6f4e9f3`; `bin/vvp` SHA-256: `6e32297c41e713fa1ad535c5c95ee690eada9114fbc3dfc7d39e681ff42a6ae7`. The final focused test snapshot was reported by the runner as `62d7166ee5c5`.
