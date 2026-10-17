# Malformed property-index metadata smoke check

Pinned base: `c7ebca768c21c251d9c165c9aff0e363768030b1`.

Slurm job 1449 compiled the registered 16-pattern property-index test with the
pinned candidate install, changed its single `%prop/index/check` operand to
`1|bad`, then ran it with `+MALFORMED`. The test passed: all 16 indexed reads
returned X, as required for invalid metadata. The smoke script runs through
`ci/run-smoke.sh` on future exact-head Fast Linux checks.

The first setup attempt (job 1448) used a source path without the overlaid
regression and stopped before running; its record is retained in r1.
