# Corrected C1 — results

Slurm job 3767 completed on DAN-DESKTOP in 0 seconds with scheduler state
`COMPLETED`, exit `0:0`. It ran the lead's exact continuous-assignment form
with pinned Icarus `cc25756d1`, `-B`, `-g2017` and `-g2023`, 1 CPU and
1 GiB. Compile and run limits were 30 seconds and `ulimit -f 262144`.

Both editions returned compile rc 1 and emitted:

```text
input/C1_struct_variable_drives_net.sv:4: error: Net `n` can not be of type `<no_type>`.
1 error(s) during elaboration.
```

No run was attempted. The earlier net-declaration-assignment variant is
preserved beside the job-3766 raw evidence; it failed with the same
diagnostic. The audit lead classified this as the same root cause as #818;
the scope-extension comment is recorded in the parent `DEDUPE.md`.
