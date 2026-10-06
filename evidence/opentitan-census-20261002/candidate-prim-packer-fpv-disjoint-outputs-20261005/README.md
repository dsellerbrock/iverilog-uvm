# OpenTitan `prim_packer` FPV per-instance outputs

`lowrisc:fpv:prim_packer_fpv:0` passes on clean OpenTitan revision
`a78922f14a8cc20c7ee569f322a04626f2ac6127` with engine
`367e44671b5aabf7786a200c2af4c3dcbd17c449bffa3ea2bc30fbfcfbaa1abc`.
The focused SVA compile has zero hard errors and zero semantic debt.

The testbench instantiated 17 `prim_packer` configurations but connected their
`ready_o`, `valid_o`, `data_o`, `mask_o`, `flush_done_o`, and `err_o` outputs to
the same top-level signals. The hash-checked build-local overlay gives each
instance a separate output slot. Shared input stimulus and each narrow
instance's data and mask slices are preserved. The pinned OpenTitan checkout
is unchanged.

The source SHA-256 is
`a69d994507dec68874b9cfa0847d4517c16ba23b554cf66b2674c11196914b4f`; the
overlay SHA-256 is
`b3c06124823d03b655c282c6a4ae8179e9330b57a48dcab4c01cd2f546aac176`.
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
  --core lowrisc:fpv:prim_packer_fpv:0 \
  --max-cores 1 \
  --jobs 1 \
  --compile-timeout 600 \
  --result-json "$OUT/result.json" \
  --result-md "$OUT/result.md"
```
