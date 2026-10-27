# §21.7.3.4 / §21.7.3.7 / §21.7.4.3.2 probes

Standards-derived expected behavior is recorded in [STANDARD.md](STANDARD.md) before execution. Probe sources are [`p21_evcd_limit.sv`](../../../tests/1800_audit/c21/p21_evcd_limit.sv) and [`p21_evcd_drv.sv`](../../../tests/1800_audit/c21/p21_evcd_drv.sv). Slurm output, exact compiler/source hashes, compile/run stdout/stderr, and generated EVCD files are in [remote-3553](remote-3553/).

The Slurm job requested 1 CPU, 1 GiB and 10 minutes; it ran for 1 second. Each compile and simulation had its own 30-second timeout. Both probes ran under `-g2017` and `-g2023` with pinned main compiler `cc25756d187314742d347267c2a513b3e640a7fb`. All eight compile/runtime status files are 0; the generated editions are byte-identical for each probe. See [RESULT.md](RESULT.md) for observations and the size-limit overshoot details.
