Partial, unqualified. The first smoke_test_mbox run on the private fixed
compiler (same diagnostic profile, 14,400 s cap) was killed with its parent
process group at about 00:02 on 2026-09-25, by the session harness rather
than the runner timeout. No summary.json was written, so this is **not** a
pass or a fail.

It reached trace commit #20,425, beyond #18,187 where the installed-tool run
died on ERR_HWIF_IN. The first DCCM loads (`exec-first-dccm-loads.log`,
starting at 0x5002007c) retired, and `sim.log` shows the SoC mailbox flow
progressing ("FW: Reading 1024 bytes from mailbox") with zero fatal, error or
ERR_HWIF_IN lines. A complete rerun, launched in its own session, is
`runs/smoke_test_mbox_r2`.
