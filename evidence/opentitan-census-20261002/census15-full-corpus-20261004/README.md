# OpenTitan census 15

The all-lanes run completed with **358 rows**. It confirms **49/49 runtime
PASS**, including Flash in 4,854.061 seconds under the 18,000-second timeout
and 9,536-MiB memory cap.

| Lane | Rows | PASS | DEBT | FAIL / setup fail / timeout / upstream invalid | Dependency only |
|---|---:|---:|---:|---:|---:|
| RTL | 185 | 33 | 8 | 25 | 119 |
| SVA | 89 | 74 | 6 | 8 | 1 |
| UVM | 35 | 22 | 13 | 0 | 0 |
| Runtime | 49 | 49 | 0 | 0 | 0 |

The [complete JSON](result-census15.json) and [matrix report](result-census15.md)
retain every row. The source snapshot was copied from OpenTitan revision
`a78922f14a8cc20c7ee569f322a04626f2ac6127`; it has no Git metadata, so the
runner recorded `revision=unknown` and `dirty=true`.

This run started before the later FuseSoC dependency overlays, RTL generic-RAM
synthesis define, and setup-warning classification. Treat its RTL/SVA/UVM
counts as a historical snapshot. The [post-fix seven-row RTL check](../../opentitan-matrix-source-dependency-overlays-20261004/README.md)
is **6 PASS, 1 ROM synthesis debt**; a new all-lanes census on the final
runner has not been run.
