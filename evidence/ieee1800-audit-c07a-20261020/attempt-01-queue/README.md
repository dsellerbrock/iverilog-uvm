# IEEE 1800-2017/2023 §7.10 queue behavior probe

- Probe: `p07_10_queue.sv`, supplied by the 1800-audit lead.
- Expected data output: `input/expected.txt`; all raw stdout, stderr, compile diagnostics and timing are preserved under `results/logs/`.
- The required invalid-write warning is reviewed separately from stdout. Quote every warning line verbatim in `RESULT.md`; optional warnings are not treated as gaps.
- Dedupe searches for the six required terms were run separately against open and closed issues; exact queries/results are in `dedupe-open-closed.txt`.
- Slurm request: 1 CPU, 1 GiB, 10 minutes; each compile/run uses a 30-second process timeout.
- Toolchain: pinned Icarus under `/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin/`.

## Archive integrity

- `input.tar.gz`: 1441 bytes; SHA-256 `b34474806af195a64b015a8ee7400be8a93ff821cddc816aa76541db650ab2db`.
- `results-3509.tar.gz`: 1595 bytes; SHA-256 `3c6eaeff45bc598888a5cb701db58bfc345ee88b7752b3e7edcdf99e38697b06`.
