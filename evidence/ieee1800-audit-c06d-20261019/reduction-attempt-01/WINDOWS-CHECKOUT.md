# Windows checkout path reproducer

Batch `test.yml` run 39705125310 failed all three Windows jobs in `actions/checkout@v4` before build or tests. The minimal reproducer was this tracked path on batch commit `18132be37631a9d07957b483ee0c9d5843f01349`:

```text
evidence/ieee1800-audit-c06d-20261019/reduction-attempt-01/r06_20_fwd_*.2017.compile.log
```

Windows Git rejected it with `error: invalid path` because the basename contains `*`. The paired compiler-output files are now named `r06_20_fwd_glob_2017.compile.log` and `r06_20_fwd_glob_2023.compile.log`; their contents are unchanged. The failure was repository checkout portability, before simulator code ran.
