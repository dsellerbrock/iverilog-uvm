# §7.10.1 invalid queue-read results

Slurm job 3562 ran on DAN-DESKTOP with pinned Icarus `cc25756d1`, 1 CPU,
1 GiB, and a 30-second timeout for each compile and run. `squeue` was empty
after output collection; Slurm accounting is unavailable on this host.

| Edition | Compile | Run | Stdout comparison |
|---|---:|---:|---|
| `-g2017` | 0 | 0 | exact match |
| `-g2023` | 0 | 0 | exact match |

Both editions printed the expected output:

```text
OOB_LOGIC 1
EMPTY_LOGIC 1
OOB_INT 0
OOB_BIT 0
PASS
```

The compiler returns X for an invalid 4-state `logic` queue read and zero
for invalid 2-state `int` and `bit` reads, including an empty `logic` queue.
This matches §§7.10.1 and 7.4.6/Table 7-1 (2017), and §§7.10.1 and
7.4.5/Table 7-1 (2023). No gap was found; no issue is proposed.

Compile and run each took 0.00 s at the timer's resolution; peak RSS was
10,780–11,660 KiB. Compiler and VVP hashes, source hashes, full stdout,
stderr, and commands are preserved in [`remote-3562/`](remote-3562/).
