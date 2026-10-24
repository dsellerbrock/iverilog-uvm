# §20.16 stochastic queue tasks — 2026-10-20

The probe checks FIFO insertion/removal, queue length/full status, and status values 0–6. The standards text and exact status/statistic tables are recorded in [STANDARD.md](STANDARD.md).

## Run

- Slurm job 3548 on DAN-DESKTOP, compiler cc25756d1; 1 CPU, 1 GiB, 10-minute limit; started 2026-10-20 13:13:46 UTC and completed at 13:13:47 UTC in 1 second with exit 0. Job metadata is in [slurm-job-3548.txt](slurm-job-3548.txt).
- Compiled and ran `p20_16_q.sv` under `-g2017` and `-g2023`, pinned with `-B /home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/lib/ivl`; each process had a 30-second timeout.
- Compiler SHA-256: `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`; VVP SHA-256: `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`; probe SHA-256: `7f7774271e59def4cdca7042c2372636908474876b443cfb65b266333e648474`.
- Raw source, compile output, runtime output, errors, run script, and Slurm log are in [remote-3548](remote-3548/); generated `.vvp` build products were removed after capture. The remote run directory was 17,077 bytes before cleanup. Slurm accounting is disabled; peak RSS is unavailable.

## Results

Both editions compiled and ran successfully, with identical output:

```text
I 0
A1 0
A2 0
A3 1
F 1 0
E 2 0
R1 10 100 0
R2 20 0
R3 3
U 2
D 6
T 4
L 5
```

The tested FIFO queue order and status codes match §20.16.6 (2023 §20.15.6). `$q_exam` was tested only with statistic code 1 (current queue length); codes 2–6 and status 7 (not enough memory) remain untested.

## Issue dedupe

Open and closed searches for `$q_initialize`, `$q_add`, `$q_remove`, `$q_full`, `$q_exam`, `stochastic`, and §§20.16/20.15 are saved as `dedupe-*.json`. All returned no matching issues. No issue was filed from this probe.
