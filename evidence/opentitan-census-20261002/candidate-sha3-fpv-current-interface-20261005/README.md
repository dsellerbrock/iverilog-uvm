# OpenTitan SHA3 FPV current DUT interface

`lowrisc:fpv:sha3_fpv:0.1` passes on clean OpenTitan revision
`a78922f14a8cc20c7ee569f322a04626f2ac6127` with engine
`367e44671b5aabf7786a200c2af4c3dcbd17c449bffa3ea2bc30fbfcfbaa1abc`.
The focused SVA compile has zero hard errors and zero semantic debt.

The FPV wrapper's wildcard connection did not match the current `sha3` port
list. The build-local overlay adds the randomness, run handshake, lifecycle,
and status/error ports; it also uses the current half-width random input and
MuBi types for `done_i` and `absorbed_o`. No signals are tied off. The pinned
OpenTitan checkout is unchanged.

The source SHA-256 is
`adb96754fe4d98ce54cf9522d1e677a8970479cb3e828cbbc5a886ebc5add9a0`; the
overlay SHA-256 is
`93a708cdec54f628780529f69ed1aaf3006809df03773b38e083fdda964275ce`.
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
  --core lowrisc:fpv:sha3_fpv:0.1 \
  --max-cores 1 \
  --jobs 1 \
  --compile-timeout 600 \
  --result-json "$OUT/result.json" \
  --result-md "$OUT/result.md"
```
