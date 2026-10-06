# OpenTitan AES wrapper single integrity driver

`lowrisc:ip:aes_wrap:1.0` passes on clean OpenTitan revision
`a78922f14a8cc20c7ee569f322a04626f2ac6127` with engine
`367e44671b5aabf7786a200c2af4c3dcbd17c449bffa3ea2bc30fbfcfbaa1abc`.
The focused RTL compile has zero hard errors and zero semantic debt.

The wrapper connected `h2d_intg` to `tlul_cmd_intg_gen`, which already
generates both command and data integrity by default, and also drove its
`data_intg` field from a second SECDED encoder. The build-local overlay removes
that redundant encoder and gives the unused AES `idle_o` signal its declared
`mubi4_t` type. The pinned OpenTitan checkout is unchanged.

The source SHA-256 is
`0738798e55b4c5543e1a92b0f7742dbb1afb459211f8592a9597ce7db11b7fbb`; the
overlay SHA-256 is
`46096cce75cf14f48738237bde617df72f81a284a69e6d0b26935e6d956957ea`.
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
  --lane rtl \
  --core lowrisc:ip:aes_wrap:1.0 \
  --max-cores 1 \
  --jobs 1 \
  --compile-timeout 600 \
  --result-json "$OUT/result.json" \
  --result-md "$OUT/result.md"
```
