# §20.16 code 3 and §20.17 PLA probes — 2026-10-20

This paired-edition Slurm batch covers the requested `$q_exam` maximum-length statistic and the PLA row-selection/asynchronous-update rules. Exact standard excerpts are in [STANDARD.md](STANDARD.md).

## Run

- Slurm job 3549 on DAN-DESKTOP, compiler cc25756d1; 1 CPU, 1 GiB, 10-minute limit; started 2026-10-20 13:16:21 UTC and completed at 13:16:22 UTC in 1 second with exit 0. Metadata is in [slurm-job-3549.txt](slurm-job-3549.txt).
- Both files were compiled and run under `-g2017` and `-g2023`, pinned with `-B /home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/lib/ivl`; each process had a 30-second timeout.
- Compiler SHA-256: `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`; VVP SHA-256: `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`.
- Probe hashes: `p20_16_q3.sv` `39e23cfb0f69b5ec45b9863bc1b0dfdd5c13ca585f13ac07a5d9ecdaae8dfba1`; `p20_17_pla.sv` `eefc201234dcd5de1ac38701d886b3644debb17c2d92f1e3f92fae50f9ac2f47`.
- Raw sources, compile/runtime output and errors, run script, and Slurm log are in [remote-3549](remote-3549/); generated `.vvp` build products were removed after capture. The remote run directory was 27,244 bytes before cleanup. Slurm accounting is disabled; peak RSS is unavailable.

## Results

`p20_16_q3` compiled and ran under both editions, matching the full queue probe output from [attempt 01](../../ieee1800-audit-c20f-20261020/attempt-01-q/README.md), with the added final line:

```text
M 3 0
```

This confirms `$q_exam` statistic code 3 reports the maximum queue length (three), after one entry has been removed and the current length is two.

`p20_17_pla` compiled under both editions, but VVP exited 1 without producing the expected `P1`–`P4` results. In each edition it reported:

```text
SORRY: .../p20_17_pla.sv:7: task $async$and$array() is not currently implemented.
SORRY: .../p20_17_pla.sv:8: task $async$or$array() is not currently implemented.
```

The compiler accepted the valid task calls, but the simulator cannot execute either asynchronous array task, so row selection and memory-change re-evaluation could not be observed.

## Issue dedupe

Open and closed searches for `$async$and$array`, `PLA`, `logic array personality`, and `20.17` are saved as `dedupe-*.json`. The only hit was closed #27, an OpenTitan UART DV runtime issue unrelated to PLA tasks; its body is in [issue-27.json](issue-27.json). The lead has the probe and dedupe results for classification.
