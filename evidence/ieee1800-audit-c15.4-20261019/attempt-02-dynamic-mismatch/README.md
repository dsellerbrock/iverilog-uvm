# §15.4 typeless-mailbox mismatch reproducer

This isolates the `try_peek`/`try_get` type-mismatch behavior after attempt 01
showed failures in both editions. The probe queues one string in a default
typeless mailbox, tries to peek and get it through an `int` reference, and
records both return values and queue counts before reading with the matching
`string` type. It is compiled and run with `-g2017` and `-g2023` using Slurm
job `3104` on DAN-DESKTOP (1 CPU, 1 GiB, 1 second; accounting storage
disabled, so peak RSS is unavailable). Both editions reproduce the same
behavior: `try_peek(int)` returns `1` with `num()==1`; `try_get(int)` returns
`1` and reduces `num()` to 0; later string operations return 0. This confirms
the probe is observing consumption on mismatched `try_get`, rather than a
bad queue-count assertion. Full output and compile/runtime logs are in
[`remote-job-3104/results.txt`](remote-job-3104/results.txt).

The raw results should distinguish a test mistake from the expected negative
return and preserve-on-mismatch behavior in IEEE 1800-2017 §15.4.6/§15.4.8 and
IEEE 1800-2023 §15.4.6/§15.4.8. Toolchain is pinned in `run.sbatch`; each
compile and simulation has a 60-second timeout.
