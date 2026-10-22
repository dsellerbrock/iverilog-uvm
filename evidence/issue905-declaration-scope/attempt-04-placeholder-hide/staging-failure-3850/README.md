# Slurm job 3850 — staging failure, not test evidence

The source archive transfer was interrupted while copying the 363 MiB archive. Job 3850 started extraction against the partial archive and failed with `gzip: unexpected end of file` before configure or tests. The transfer later completed and its SHA-256 matched the local archive; the verified archive was copied into fresh run 0040 for job 3851. No test conclusion is attributed to job 3850.
