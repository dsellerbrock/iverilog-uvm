# §11.3.2–§11.4.11 operator probe

Ran Slurm job 3539 on DAN-DESKTOP with pinned Icarus 13.0-devel (`cc25756d1`), `-B` set to the protected audit toolchain, 1 CPU, 1 GiB RAM, and 30-second per-process timeouts. The complete transcript and per-edition stdout/stderr are in `slurm-3539.out` and `results-3539/`.

Both `-g2017` and `-g2023` compiled and ran with exit code 0, producing identical output:

```text
BW 1000 11xx 01xx 01xx 10xx
RD 1 x 0 x 1 1 x 0 1 0
SH 00100101 10110000 11100101 00100101 00100101
SX xxxxxxxx
CQ 10xx 0000
PR 6 64 4 1110 1 3
IL -4
IL 1431655761
IL -4
IL 1
```

The values match the cited 2017/2023 tables and §11.3.3 example. In particular, Table 11-2 marks `**` left-associative, so `2 ** 3 ** 2` is 64. The lead's provisional expectation of 512 conflicted with the table; the probe and this evidence use the standard's 64. No issue was filed for that expression.

Open-and-closed searches for all eight terms listed in `dedupe-searches.sh` are saved as `dedupe-*.json`; the returned issues concern real operands in §11.3.1, conditional predicate syntax, or unrelated clauses. The remote run directory was removed after copying evidence; `du -sb` recorded 17,341 bytes freed.
