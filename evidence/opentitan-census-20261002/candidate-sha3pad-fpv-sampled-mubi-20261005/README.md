# OpenTitan SHA3PAD FPV interface follow-up

`lowrisc:fpv:sha3pad_fpv:0.1` passes its focused SVA compile with zero hard
errors and zero semantic debt on engine
`367e44671b5aabf7786a200c2af4c3dcbd17c449bffa3ea2bc30fbfcfbaa1abc` and clean
OpenTitan commit `a78922f14a8cc20c7ee569f322a04626f2ac6127`.

The build-local source overlay updates the FPV wrapper to the current SHA3PAD
and Keccak round ports, uses the DUT's MuBi4 control types, and compares the
byte-reversed digest through a packed signal. The packed signal lets the
assertion sampler read the digest without a live unpacked-array expression.
The pinned OpenTitan checkout remains unchanged.

The source SHA-256 is
`d88ed8ec4aecc66b229a787843bf04b0fb9c3ae580e33c11deebfcd8f503abe0`; the
overlay SHA-256 is
`c49982baddface8c04575e59504bcfc981d36d8860c00ab179b03b51ae4b4584`. The
[patch](source-overlay.patch) applies cleanly to the pinned commit. See the
[machine result](result.json), [matrix report](result.md), [setup log](setup.log),
and [compile log](compile.log).

This focused follow-up does not recompute the frozen 309-row census. That
snapshot still records SHA3PAD as upstream-invalid; this verified overlay makes
the focused row pass.

To reproduce, run from the Icarus repository with Python 3.13 and the same
FuseSoC/UVM tools used by the census:

```sh
/opt/homebrew/opt/python@3.13/bin/python3.13 scripts/opentitan_matrix.py \
  --opentitan-root "$OT_ROOT" \
  --build-root "$BUILD_ROOT" \
  --iverilog "$IVL" \
  --uvm-home "$UVM_HOME" \
  --fusesoc "$FUSESOC" \
  --fusesoc-python "$OT_PY" \
  --lane sva \
  --core lowrisc:fpv:sha3pad_fpv:0.1 \
  --jobs 1 \
  --setup-timeout 600 \
  --compile-timeout 600 \
  --commercial-unsafe \
  --native-pkg-config openssl \
  --native-pkg-config libelf \
  --result-json "$OUT/result.json" \
  --result-md "$OUT/result.md"
```
