# IEEE 1800 §15.4 mailbox probe, attempt 02

- Host: DAN-DESKTOP, Slurm job 3368; 1 CPU, 1 GiB; per-command timeout 20 s.
- Baseline toolchain: source commit `cae035642e056644274a01e98d4422ce286685b4`; `iverilog` SHA-256 `6f64b9987e04069dde9904cd1f0790d3430e34dbebb7908db159e6ec5290e330`; `vvp` SHA-256 `979d745f46bf952c86b1f09255e2256a6eec2bbef15b5c11634c8b4c95013309`.
- Fresh run directory: `/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c15.4-20261020-02/`.
- Probe input archive SHA-256: `4bfaf72d4df0addefeff1fc43d6c4bd924ce0d3ef4074197a2e3a9abc18dbc50`.

## Raw results

Both `-g2017` and `-g2023`:

- Positive `p15_04a_mailbox.sv`: compile 0, run 0, `RESULT pass=15 fail=1`; the original `waiters_fifo` assertion also required process resumption order. The reduction in [attempt 03](../attempt-03/RESULT.md) confirms FIFO message assignment (`w1=100`, `w2=200`, `w3=300`) and observes resume order 3,2,1; the resume-order check has been removed from the probe.
- Runtime message-type mismatch `r15_get_mismatch.sv`: compile 0, run 0, output `SURVIVED 0`; no run-time diagnostic on this baseline toolchain.
- Parameterized mailbox `put` with `int` and `get` into `int` negatives: both rejected at compile time with the expected §15.4.9 equivalent-message-type diagnostic.

The full raw TSV, metadata, compile logs, run logs, input snapshot, and batch script are stored under this directory. The open/closed dedupe search is [`dedupe-open-closed.txt`](../dedupe-open-closed.txt): only #695 matched; it concerns `try_get`/`try_peek` mismatch return values and does not cover ordinary blocking `get`.

Attempt 01 was not a test result; it had the archive path error described in [attempt 01](../attempt-01/README.md). Attempt 02 used the corrected flat archive in a fresh run directory.

**Provenance correction:** This toolchain is older than the current source baseline. `cae035` to `8c95b5` changes 105 code paths; current `origin/main` is `c41e504`, and `8c95b5` to `c41e504` changes no source, test, or build paths. Therefore this result does not verify current-main behavior. The lead filed #826 from this initial result; current-main confirmation is running in [attempt 04](../attempt-04-current-main/).
