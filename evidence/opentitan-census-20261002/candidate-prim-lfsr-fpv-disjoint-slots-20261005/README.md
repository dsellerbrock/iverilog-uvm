# OpenTitan `prim_lfsr` FPV disjoint instance indices

`lowrisc:fpv:prim_lfsr_fpv:0.1` passes on clean OpenTitan revision
`a78922f14a8cc20c7ee569f322a04626f2ac6127` with engine
`367e44671b5aabf7786a200c2af4c3dcbd17c449bffa3ea2bc30fbfcfbaa1abc`.
The focused SVA compile has zero hard errors and zero semantic debt.

The original testbench reused vector indices between linear and nonlinear
GalXor instances, then reused indices between the linear and nonlinear
FibXnor instances. The build-local overlay reserves disjoint index bands:
`[0,G)`, `[G,2G)`, `[2G,2G+F)`, and `[2G+F,2G+2F)`, where `G` and `F` are
the configured GalXor and FibXnor width counts. Nonlinear instances use sparse
slots inside their reserved band. This removes duplicate `state_o` drivers
and input aliases. The pinned OpenTitan checkout is unchanged.

The source SHA-256 is
`e43d078287df5950fd78d33d60c6a02a60666caa3ae5cb877d42db8da20c33ee`; the
generated overlay SHA-256 is
`7a7d252fbd82c28d7b17bc4718be5c8bd5f5350a143aa5396a4c096912f2f72c`.
See the [reproducible patch](source-overlay.patch), [machine result](result.json),
[matrix report](result.md), [setup log](setup.log), and [compile log](compile.log).
The frozen 309-row census is unchanged.

To reproduce the focused compile:

```sh
python scripts/opentitan_matrix.py \
  --opentitan-root "$OT_ROOT" \
  --build-root "$BUILD_ROOT" \
  --iverilog "$IVL" \
  --fusesoc "$FUSESOC" \
  --fusesoc-python "$OT_PY" \
  --lane sva \
  --core lowrisc:fpv:prim_lfsr_fpv:0.1 \
  --max-cores 1 \
  --jobs 1 \
  --compile-timeout 600 \
  --result-json "$OUT/result.json" \
  --result-md "$OUT/result.md"
```
