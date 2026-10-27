# Isolated `$printtimescale` results — Slurm job 3774

Pinned Icarus `cc25756d187314742d347267c2a513b3e640a7fb`; DAN-DESKTOP, 1 CPU/1 GiB. Raw logs, results, scheduler record and input hashes are under `raw-slurm-3774/`.

| Form | `-g2023` | `-g2017` observation |
|---|---|---|
| `$printtimescale($root)` | compile 0; runtime 1: `$printtimescale's argument must have a module, given a vpiConstant.` | Same runtime rejection; not classified under 2017 |
| `$printtimescale($unit)` | compile 3: `A package scope argument is only valid for $timeunit or $timeprecision.` | Same compile rejection; not classified under 2017 |
| `$printtimescale()` | compile/run 0/0; `Time scale of (a_dat) is 1ms / 1us` | compile/run 0/0; same output |
| `$printtimescale(b_dat.c1)` | compile/run 0/0; `Time scale of (b_dat.c1) is 1ns / 1ns` | compile/run 0/0; same output |

IEEE 1800-2023 §20.4.2's printed example on p.625 expects:

```text
Time scale of ($root) is 1fs / 1fs
Time scale of ($unit) is 100ps / 10fs
Time scale of (a_dat) is 1ms / 1us
Time scale of (b_dat.c1) is 1ns / 1ns
```

The implementation passes the current-scope and hierarchical forms in both editions. The isolated `$root` and `$unit` forms each fail in 2023.

## Dedupe

Fresh live open+closed snapshot: 429 issues (302 open, 127 closed), saved in `dedupe-live-all-issues.json`. Literal title/body hits: `$timeunit` and `$timeprecision` → closed #458; `$unit` → closed #19 only, a broad compilation-unit-scope issue that does not mention `$printtimescale`; `$stacktrace` → closed #459 and #47; no hits for `$printtimescale`, `$root`, `timescale retrieval`, or §20.4.1/§20.4.2/§20.17.2. No issue filed pending audit-lead classification.
