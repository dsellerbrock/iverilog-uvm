# §35.5.5–§35.5.6 chandle DPI ABI results

Slurm job 3563 ran on DAN-DESKTOP with pinned Icarus `cc25756d1`, GCC
15.2.0, 1 CPU, 1 GiB, and 30-second per-command timeouts. Both editions
compiled, linked, and ran successfully:

| Edition | Compile | Link | Run | Stdout |
|---|---:|---:|---:|---|
| `-g2017` | 0 | 0 | 0 | exact match |
| `-g2023` | 0 | 0 | 0 | exact match |

Both printed `PASS m10j_dpi_chandle_abi_test`. The test allocates a C
`int *`, returns it as `chandle`, passes the pointer to C for reading, then
passes it to C for `free()`. This tests the §35.5.5 result and §35.5.6
formal-argument paths, with the Annex H.1 `void *` mapping.

The existing source emits the same warning in both editions about its
initialized static variable lacking an explicit lifetime; the C ABI checks
still pass. Compile/link/run times were 0.00/0.01–0.02/0.00 seconds, with
peak RSS 11,596–25,056 KiB. Compiler, VVP, GCC, and source hashes plus full
logs are in [`remote-3563/`](remote-3563/). `squeue` was empty after output
collection; Slurm accounting is unavailable on this host.

No conformance gap was found; no issue is proposed. This probe covers only
the tested input/result round trip, not chandle output/inout, array, or class
property cases.
