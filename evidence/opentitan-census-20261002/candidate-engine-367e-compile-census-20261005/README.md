# OpenTitan candidate-engine 367e compile census

This compile-only census completed all 309 RTL, SVA, and UVM rows against
clean OpenTitan revision `a78922f14a8cc20c7ee569f322a04626f2ac6127` using
Icarus engine `367e44671b5aabf7786a200c2af4c3dcbd17c449bffa3ea2bc30fbfcfbaa1abc`.
It ran serially with UVM 1.2, `-gcommercial-unsafe`, and OpenSSL/libelf native
dependencies. The matrix runner applied its hash-checked, per-core build-local
overlays. The pinned OpenTitan checkout is unchanged.

| Lane | PASS | Dependency only | DEBT | FAIL | Setup fail | Upstream invalid |
|---|---:|---:|---:|---:|---:|---:|
| RTL | 54 | 119 | 0 | 3 | 7 | 2 |
| SVA | 86 | 1 | 1 | 0 | 0 | 1 |
| UVM | 17 | 0 | 5 | 13 | 0 | 0 |
| **Total** | **157** | **120** | **6** | **16** | **7** | **3** |

These 309 entries are compile-matrix rows (`lane` + FuseSoC core + target),
not 309 runtime tests. `DEPENDENCY_ONLY` means FuseSoC reported that the core
has no standalone top-level, so the runner did not compile it by itself. The
120 rows are 119 RTL and 1 SVA; by namespace they are 81 `prim`, 23 `ip`, 9
`systems`, 4 `ibex`, 2 `tlul`, and 1 `fpv` cores. These are non-standalone
dependency cores (including packages and filesets), not 120 Icarus defects to
patch individually. The runner labels
them `compiled_through_parent_toplevel`, but this result does not record the
specific parent compile proving each dependency was included; that coverage
mapping still needs verification before counting them as individually proven.

Compared with the older engine `890c…` census, this result has 20 more PASS
rows, 13 fewer DEBT rows, and 7 fewer upstream-invalid rows. The regular UVM
lane still has 13 compile failures and 5 debt rows; the separate
[patched UVM lane](../candidate-patched-uvm-final-20261005/README.md) passes
35/35 on engine `367e…`.

The three RTL failures are CW310, CW310 Hyperdebug, and CW340 tops that need
Xilinx primitives such as `MMCME2_ADV` and `BUFG`. The three upstream-invalid
rows are `ibex_simple_system_cosim`, `chip_englishbreakfast_cw305`, and
`sha3pad_fpv`. Seven setup failures remain in the Ibex compliance/register
cores, `primgen`, and English Breakfast generation targets. The six DEBT rows
are the Earl Grey ASIC SVA top and five baseline UVM rows (`csrng`, `pattgen`,
`rv_timer`, `spi_device`, and `sram_ctrl`). Per-row details are in the
[machine result](result.json) and [table](result.md); the exact run is in
[`runner.log`](runner.log).

The frozen 309-row table retains its original classifications. A later
focused SHA3PAD FPV follow-up passes on the same engine; applying that one
row-level update gives 158 PASS and 2 upstream-invalid rows. See the
[focused result](../candidate-sha3pad-fpv-sampled-mubi-20261005/result.json).

This census excludes runtime. The separate selected 49/49 runtime gate now
passes on engine `367e…`. Thus these compile results, plus the 35/35 patched
UVM result, do not establish full OpenTitan completion.

To reproduce the census:

```sh
python scripts/opentitan_matrix.py \
  --opentitan-root "$OT_ROOT" \
  --build-root "$BUILD_ROOT" \
  --iverilog "$IVL" \
  --uvm-home "$UVM_HOME" \
  --fusesoc "$FUSESOC" \
  --fusesoc-python "$OT_PY" \
  --lane rtl --lane sva --lane uvm \
  --jobs 1 \
  --setup-timeout 600 \
  --compile-timeout 600 \
  --commercial-unsafe \
  --native-pkg-config openssl \
  --native-pkg-config libelf \
  --result-json "$OUT/result.json" \
  --result-md "$OUT/result.md"
```
