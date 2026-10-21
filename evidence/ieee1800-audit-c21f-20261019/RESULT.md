# §21.7.1 and extended VCD probe results

Host: macOS localrun. Toolchain: compiler `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`; VVP `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`. Each run compiled first, ran only after a successful compile, and exited 0. Each row has an isolated cwd; `command.txt` and `run.log` preserve the full command, exit code, wall time, and peak RSS.

| Probe | Edition | Wall | Peak RSS | Observation |
|---|---:|---:|---:|---|
| lv1 | 2017 | 0.06 s | 6,569,984 B | Only top.a declared |
| lv1 | 2023 | 0.05 s | 6,619,136 B | Same |
| lv2 | 2017 | 0.06 s | 6,537,216 B | Only top.m1.b declared |
| lv2 | 2023 | 0.05 s | 6,635,520 B | Same |
| lv3 | 2017 | 0.08 s | 6,602,752 B | top.a and direct child m1.b; no m1.m2.c |
| lv3 | 2023 | 0.06 s | 6,602,752 B | Same |
| lv4 | 2017 | 0.05 s | 6,586,368 B | Only selected top.m1.b declared |
| lv4 | 2023 | 0.05 s | 6,602,752 B | Same |
| limit | 2017 | 0.06 s | 6,651,904 B | 359-byte file; ends with limit-reached comment at #6 |
| limit | 2023 | 0.05 s | 6,619,136 B | Same |
| ports | 2017 | 0.07 s | 6,701,056 B | 672-byte EVCD; off interval and checkpoints recorded |
| ports | 2023 | 0.05 s | 6,733,824 B | Same |
| portsdef | 2017 | 0.04 s | 6,569,984 B | `$dumpports;` creates default dumpports.vcd |
| portsdef | 2023 | 0.04 s | 6,553,600 B | Same |
| portsdef_empty | 2017 | 0.05 s | 6,569,984 B | `$dumpports();` creates default dumpports.vcd |
| portsdef_empty | 2023 | 0.06 s | 6,602,752 B | Same |

The tested `$dumpvars` depth/scope matched the lead's expected membership. `$dumplimit(300)` reported the limit and stopped after the #6 record; the 359-byte result conforms because the standard requires stopping at the threshold and inserting a comment but does not specify the final size. The `ports` EVCD records no `d` update at #40 while port dumping is off, resumes current port values at #50, and checkpoints at #70. The tested `$dumpports` formats conform. `$dumpportsflush` returns normally. The default forms create files when called from a module with no ports; these probes verify syntax and filename, not default-scope port selection. `$dumpportslimit` remains untested.
