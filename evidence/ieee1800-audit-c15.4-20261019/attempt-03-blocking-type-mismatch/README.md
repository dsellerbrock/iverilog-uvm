# §15.4 blocking mailbox type-mismatch probes

These paired-edition probes check the run-time-error requirement for `get()`
and `peek()` with a non-equivalent reference type on the default typeless
mailbox (2017 §15.4.5/§15.4.7 and 2023 §15.4.5/§15.4.7). They record whether
the operation returns, any runtime diagnostic, and the final queue count.
Each operation runs in its own simulation so one result cannot mask the other.
Slurm job `3105` completed all four cases on the pinned `cae035642e056644274a01e98d4422ce286685b4` toolchain (1 CPU, 1 GiB, 1 second; accounting storage disabled, so peak RSS is unavailable). In both editions, mismatched `get(int)` consumed the string and returned the destination value as zero with no diagnostic; mismatched `peek(int)` copied zero with no diagnostic and left the message queued. Raw results and all per-test logs are in [`remote-job-3105/results.txt`](remote-job-3105/results.txt).
