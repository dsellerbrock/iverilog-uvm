# §7.10 invalid queue-read probe — superseded design

The first test design incorrectly expected an out-of-range read from an
`int` queue to return X. IEEE 1800 §6.11 defines `int` as 2-state, so the
correct §7.4.6/§7.4.5 Table 7-1 value is zero. Slurm job 3561 compiled both
editions and produced `OOB_INT 0`, then stopped at the invalid assertion.
This is a test-design error, not a simulator finding; the raw input, outputs,
and hashes are retained under [`remote-3561/`](remote-3561/).

The corrected probe is recorded in `attempt-05-invalid-read-types/`.
