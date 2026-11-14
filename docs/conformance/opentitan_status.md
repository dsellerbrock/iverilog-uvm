# OpenTitan runtime matrix: status

The latest OpenTitan runtime and compile-census results, with links to their evidence. Moved from the
[README](../../README.md) on 2026-11-14; the numbers are as of 2026-10-05. [CURRENT_WORK](CURRENT_WORK.md) has the
latest committed evidence across all workloads.

The selected OpenTitan runtime gate now passes **49/49 targets** on candidate
engine `367e…`; the aggregate combines 48 completed rows with a focused I2C
replay after fixing idempotent overlay staging. The 309-row compile census
still records 157 PASS, 120 dependency-only, 6 DEBT, 16 FAIL, 7 setup failures,
and 3 upstream-invalid rows, so this does not close the broader compile audit.
See the [engine 367e runtime result](../../evidence/opentitan-census-20261002/candidate-runtime-engine-367e-aggregate-20261005/README.md),
[latest candidate compile census](../../evidence/opentitan-census-20261002/candidate-engine-367e-compile-census-20261005/README.md),
[historical candidate compile census](../../evidence/opentitan-census-20261002/candidate-census18-pinned-compile-20261005/README.md),
[latest patched UVM lane](../../evidence/opentitan-census-20261002/candidate-patched-uvm-final-20261005/README.md),
[engine 890c candidate runtime recheck](../../evidence/opentitan-census-20261002/candidate-runtime-recheck-20261005/README.md),
[historical 49/49 result](../../evidence/opentitan-census-20261002/census18-xpack-runtime-20261005/README.md),
and [49/49 reproduction guide](opentitan_49of49_reproduction.md).
The `sha3pad_fpv` row has since passed a focused overlay compile; the frozen
census totals have not been recomputed. See its
[result and patch](../../evidence/opentitan-census-20261002/candidate-sha3pad-fpv-sampled-mubi-20261005/README.md).
The [matrix runner reference](opentitan_matrix.md) and
[hot-path analysis](../../evidence/opentitan-census-20261002/census12-full-corpus-20261003/HOTPATHS.md)
cover runner behavior and measured optimization work.
The [optimization plan and reproducers](opentitan_hotpath_optimization.md)
link to bounded fixtures and measured next steps.
