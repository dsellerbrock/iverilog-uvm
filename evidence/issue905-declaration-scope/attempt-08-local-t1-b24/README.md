# Local T0/T1 rerun on PR head b24b06d672d7340c4908f4d689bd322617573cca

The installed compiler was built from `a139d2eb3b7ac16530578ce3cf47a1b28576b906`; the C++ implementation is unchanged through `b24b06d6`, which only changes test include flags. On that current regression-list head, localrun passed T0 legacy 4/4, T0 JSON 4/4, T1 legacy 20/20, and T1 JSON 18/18. `localrun.out` records 11.56 seconds and 32,849,920 bytes maximum RSS. T1 raw logs are retained in `raw-legacy-test-logs/` and `raw-json-test-logs/`.

The Slurm job 3851 had already passed build, `make check`, install, and smoke on the same compiler implementation. No gold files changed.
