# §18.17.3 duplicate-default runtime reducer

**Host:** DAN-DESKTOP Slurm, job 3396, 2026-10-20. **Input base:** `cc25756d187314742d347267c2a513b3e640a7fb`. **Compiler:** Icarus Verilog 13.0-devel (`cc25756d1`); compiler SHA-256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`; `vvp` SHA-256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`. Each compile/runtime process had a 30-second timeout. Slurm accounting is disabled and `seff` unavailable; exact compile/run return codes and logs are preserved here.

Both editions compile and run the invalid two-`default` production with rc=0 and no diagnostic. The valid one-`default` control also compiles/runs in both editions and prints `DEFAULT`. IEEE 1800-2017/2023 §18.17.3 says multiple defaults in one case production statement are illegal.

Sources and results are preserved in this directory. The exact duplicate-default failure was already deduped against all open and closed issues with `randsequence`, `randcase`, `production`, and `rand join` before the lead files any issue; all four searches returned no results.
