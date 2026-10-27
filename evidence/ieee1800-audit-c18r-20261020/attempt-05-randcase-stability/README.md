# §18.14.2 randcase thread-stability probe

IEEE 1800-2017/2023 §18.14.2 says random values selecting `randcase` branches
are independent of thread execution order. This probe seeds one parent process,
then runs two sibling processes that each record sixteen equal-weight branch
choices. The paired builds reverse which sibling is delayed; `$urandom()` in
each sibling is a process-seeding control. Both editions and each schedule are
repeated with a fixed seed.

Probe SHA-256: `76eb6bc92a34ecb66a46f3d1b26162c31bb24e57b382c49260f8f0d1e7476028`.
Slurm job `3577` on `DAN-DESKTOP` compiled and ran both editions and both
schedules twice; every compile, run, and replay control passed. Reversing which
sibling was delayed preserved the same values in both editions:
`A_u=3641758753`, `B_u=655509810`, `A_rc=0012110010221022`, and
`B_rc=0021121110012122`. Raw outputs and result are retained under `logs/`.
