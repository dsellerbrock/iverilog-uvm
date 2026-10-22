# Results — Slurm job 3704

- Host: DAN-DESKTOP; request: 1 CPU, 1 GiB; compile and run commands had 30-second timeouts.
- Toolchain: Icarus source commit `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`; `iverilog` SHA-256 `9760f8c1ab8ad03d64761b257db74ff07603a15c4d44d2bcdba75073f006911c`; `vvp` SHA-256 `7fa3224c44e69b555fa86c1e3e048fa2709780276c6417ff8b7a7f0d63241c02`.
- Both editions compiled and ran successfully; both matched the expected output. The preserved job output ends with `FINAL_STATUS=0`, and `squeue -j 3704` was empty. Slurm accounting storage is disabled, so elapsed time, peak RSS, and scheduler exit code were unavailable.

```text
R1 act b=0
R2 inact b=0
R4 react b=1
R5 post b=1 c=2 d=0
```

This confirms the tested Active-to-Inactive-to-NBA observation, program Reactive observation, Postponed `$strobe` observation, ordered updates from two NBAs to the same 2-bit variable, and capture of old `c` by `d` in both `-g2017` and `-g2023`. The first attempt's scalar `c` correctly truncated 2 to 0; it is preserved separately and is not treated as a simulator failure. Raw logs are in [`raw-slurm/`](raw-slurm/).
