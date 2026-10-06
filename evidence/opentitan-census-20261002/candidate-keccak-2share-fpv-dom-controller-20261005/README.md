# Keccak 2-share FPV DOM controller update

`lowrisc:fpv:keccak_2share_fpv:0.1` passes on clean OpenTitan revision
`a78922f14a8cc20c7ee569f322a04626f2ac6127` with engine
`367e44671b5aabf7786a200c2af4c3dcbd17c449bffa3ea2bc30fbfcfbaa1abc`.
Setup and compile return zero, with no actionable setup warnings, compile
errors, or semantic debt.

The hash-checked, build-local overlay repairs the missing `StPhase1` case
closure and models the current `keccak_round` DOM control sequence. It keeps
the existing assumptions, digest check, and masked-versus-unmasked assertion;
`rand_aux_i` still selects lane order, while the four DOM controls now match the
DUT interface. The pinned OpenTitan source remains clean. See the
[reproducible patch](source-overlay.patch), [machine result](result.json),
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
  --core lowrisc:fpv:keccak_2share_fpv:0.1
```

The runner verifies the pinned source and generated overlay hashes before
compiling the row.
