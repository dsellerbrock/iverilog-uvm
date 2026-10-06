# Keccak round FPV MuBi clear input

`lowrisc:fpv:keccak_round_fpv:0.1` passes on clean OpenTitan revision
`a78922f14a8cc20c7ee569f322a04626f2ac6127` with engine
`367e44671b5aabf7786a200c2af4c3dcbd17c449bffa3ea2bc30fbfcfbaa1abc`.
Setup and compile return zero, with no actionable setup warnings or semantic
debt.

The testbench's scalar `clear` signal is now typed `prim_mubi_pkg::mubi4_t`
and uses the package's `MuBi4False` and `MuBi4True` encodings. Its clear pulse
and assertions are otherwise unchanged. The hash-checked overlay leaves the
pinned OpenTitan checkout untouched. See the [reproducible patch](source-overlay.patch),
[machine result](result.json), [matrix report](result.md), [setup log](setup.log),
and [compile log](compile.log). The frozen 309-row census is unchanged.

To reproduce the focused compile:

```sh
python scripts/opentitan_matrix.py \
  --opentitan-root "$OT_ROOT" \
  --build-root "$BUILD_ROOT" \
  --iverilog "$IVL" \
  --fusesoc "$FUSESOC" \
  --fusesoc-python "$OT_PY" \
  --lane sva \
  --core lowrisc:fpv:keccak_round_fpv:0.1
```
