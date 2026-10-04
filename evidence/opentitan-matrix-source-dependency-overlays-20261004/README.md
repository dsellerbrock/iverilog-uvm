# OpenTitan matrix source dependency overlays

Three pinned Earlgrey-PROD-M6 FuseSoC cores omit direct dependencies used by
their RTL. The matrix runner creates build-local core overlays that declare
the missing providers; it does not modify the OpenTitan input tree.

| Source core | Added dependency declarations |
|---|---|
| `hw/ip/prim/prim_mubi.core` | `lowrisc:prim:flop_2sync` |
| `hw/top_earlgrey/ip_autogen/flash_ctrl/flash_ctrl_prim_reg_top.core` | `lowrisc:prim:reg_we_check` |
| `hw/ip/otp_ctrl/otp_ctrl_prim_reg_top.core` | `lowrisc:prim:reg_we_check`, `lowrisc:tlul:trans_intg`, `lowrisc:tlul:adapter_reg`, `lowrisc:prim:subreg` |

The `prim_mubi` omission prevented FuseSoC from generating the generic
`prim_flop_2sync` module used by its synchronizers. The two register-top cores
declared only their package dependency, leaving the register-check, TL-UL, and
subregister modules out of their resolved source lists.

## Focused result

The matrix driver's self-test passed. A targeted RTL rerun with the overlays
passed all five affected rows:

| Core | Result |
|---|---|
| `lowrisc:ip:lc_ctrl_pkg:0.1` | PASS |
| `lowrisc:ip:otp_ctrl_pkg:1.0` | PASS |
| `lowrisc:tlul:trans_intg:0.1` | PASS |
| `lowrisc:ip:flash_ctrl_prim_reg_top:1.0` | PASS |
| `lowrisc:ip:otp_ctrl_prim_reg_top:1.0` | PASS |

The tested OpenTitan source snapshot has no Git metadata; its matrix report
records `revision=unknown` and a dirty source state. The overlay and source
SHA-256 fingerprints recorded by that report are:

| Source core | Source SHA-256 | Overlay SHA-256 |
|---|---|---|
| `hw/ip/prim/prim_mubi.core` | `8760c7af65f75ccd03cede48f22e110a116c40f6f7516017e8ea05a8cb0608cf` | `9d30aaeacde9beb2e58a3d7395e34101af55d0fde827798835d18638d62c77df` |
| `hw/top_earlgrey/ip_autogen/flash_ctrl/flash_ctrl_prim_reg_top.core` | `ffcc9454268f57356ccae63bf988a16c80eea40cee0aef6c75feff0116821849` | `5857645cdfe0f8840f382096956782b49f9f8ec6eb667f92132a217c0b1e427d` |
| `hw/ip/otp_ctrl/otp_ctrl_prim_reg_top.core` | `34ff856cef2f658bff1a6fc86c4bea068979feb97c900286fc8284e25865bafb` | `1c07622516c3e0e62047b4bc1613845f68fcd8e9b1926464da77330eed19681e` |

The tested Icarus driver SHA-256 was
`02f5a2f162250fd33b2a7a3c22109fd66f047dd890caa58b5fe09a510a1785f1`; the
compiler engine SHA-256 was
`8dae711b38f7229b74b29455db587238ef76452928a66faeb5085aa429ef184c`.

## Reproduction

Use the same Python and FuseSoC environment, OpenTitan snapshot, and compiler
for comparable results. Replace the paths with local locations:

```sh
"$OT_PY" scripts/opentitan_matrix.py \
  --opentitan-root /path/to/opentitan-source \
  --build-root /path/to/build/missing-dependencies \
  --iverilog /path/to/iverilog/bin/iverilog \
  --fusesoc "$OT_FUSESOC" --fusesoc-python "$OT_PY" \
  --lane rtl \
  --core lowrisc:ip:lc_ctrl_pkg:0.1 \
  --core lowrisc:ip:otp_ctrl_pkg:1.0 \
  --core lowrisc:tlul:trans_intg:0.1 \
  --core lowrisc:ip:flash_ctrl_prim_reg_top:1.0 \
  --core lowrisc:ip:otp_ctrl_prim_reg_top:1.0 \
  --jobs 1
```

The runner records the source and generated overlay hashes in the result JSON
under `metadata.matrix_source_core_overrides`.
