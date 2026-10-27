# Clause 20 probe results — Slurm job 3773

Pinned Icarus `cc25756d187314742d347267c2a513b3e640a7fb`; DAN-DESKTOP, 1 CPU/1 GiB. Full scheduler record, stdout, result rows, version strings and raw compile/run logs are in `raw-slurm-3773/`.

- E1 §20.4.1, `-g2023`: compile/run 0/0. Values match all four expected exponent pairs: `$root` −15/−15, `$unit` −10/−14, `a_dat` −3/−6, `b_dat.c1` −9/−9. Exact output is in `results.tsv`. Under `-g2017`, compile rejects `$timeunit`/`$timeprecision` as requiring IEEE 1800-2023; recorded only.
- E2 §20.4.2, combined example, `-g2023`: compile fails on `$printtimescale($unit)` with “A package scope argument is only valid for $timeunit or $timeprecision.” Attempt 02 isolates the four argument forms: `$unit` is rejected at compile time under 2023, `$root` compiles but fails at runtime, and current-scope plus hierarchical forms pass. The 2017 results are recorded only for `$root` and `$unit`; current-scope and hierarchical forms pass under both editions.
- S1 §20.17.2, `-g2023`: compile/run 0/0; function returns nonempty string (`len_ok=1`) and task prints call-stack information. Under `-g2017`, compiler rejects both `$stacktrace` forms; recorded only.

Pre-probe dedupe: 429 issues (302 open, 127 closed); #458 closed covers `$timeunit`/`$timeprecision`, #459 closed covers the function form of `$stacktrace`; #47 is a broad fallback issue. `$printtimescale` and `$root` have no title/body hits. The only `$unit` hit is closed #19, broad compilation-unit scope and not `$printtimescale($unit)`.

No issue filed pending isolation and audit-lead classification.
