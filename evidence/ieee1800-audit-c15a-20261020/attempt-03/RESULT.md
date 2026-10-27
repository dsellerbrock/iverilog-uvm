# IEEE 1800 §15.4 waiter-order reduction

- Slurm job 3369 on DAN-DESKTOP; 1 CPU, 1 GiB; per-command timeout 20 s.
- Toolchain is unchanged from attempt 02: baseline source commit `cae035642e056644274a01e98d4422ce286685b4`, compiler SHA-256 `6f64b9987e04069dde9904cd1f0790d3430e34dbebb7908db159e6ec5290e330`, VVP SHA-256 `979d745f46bf952c86b1f09255e2256a6eec2bbef15b5c11634c8b4c95013309`.
- `r15_04b_waiter_assignment.sv` compiled and ran in both editions (rc 0).
- Both outputs: `ASSIGN w1=100 w2=200 w3=300`, `RESUME count=3 order=3,2,1`, `RESULT pass=1 fail=0`.

The original `waiters_fifo` failure was a probe overconstraint: FIFO message assignment passed, while the independent process-resumption order was reverse FIFO. This reduction confirms the standard behavior under test without asserting a scheduling order for resumed processes. Raw results and logs are under `raw/`. Because this toolchain predates the current-main source baseline, the exact result will be repeated with the current-main build in attempt 04.
