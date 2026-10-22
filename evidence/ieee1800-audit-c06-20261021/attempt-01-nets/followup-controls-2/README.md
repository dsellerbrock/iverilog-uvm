# Clause 6.6 follow-up controls 2

Paired probes isolating unpacked-struct assignment forms from user-defined
nettype resolver return-type support. Each source is compiled and, when it
compiles, run independently with `-g2017` and `-g2023` on pinned Icarus
`cc25756d1`. The Slurm harness applies `ulimit -f 262144` to every compile
and run, plus a 30-second process timeout.

Expected successful outputs: C1-C3 print `1 3`; U1c/U2c print `3.5`; U3c
prints `9.0` while forced and `3.5` after release. A failed or capped case is
retained as evidence and interpreted against the cited IEEE clauses by the
audit lead.
