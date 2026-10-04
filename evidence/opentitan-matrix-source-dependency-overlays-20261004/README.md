# OpenTitan matrix source dependency overlays

Six pinned Earlgrey-PROD-M6 FuseSoC cores omit direct dependencies used by
their RTL. The matrix runner creates build-local core overlays that declare
the missing providers; it does not modify the OpenTitan input tree.

| Source core | Added dependency declarations |
|---|---|
| `hw/ip/prim/prim_mubi.core` | `lowrisc:prim:flop_2sync` |
| `hw/ip/prim/prim_ram_1p_adv.core` | `lowrisc:prim:mubi` |
| `hw/top_earlgrey/ip_autogen/flash_ctrl/flash_ctrl_prim_reg_top.core` | `lowrisc:prim:reg_we_check` |
| `hw/ip/otp_ctrl/otp_ctrl_prim_reg_top.core` | `lowrisc:prim:reg_we_check`, `lowrisc:tlul:trans_intg`, `lowrisc:tlul:adapter_reg`, `lowrisc:prim:subreg` |
| `hw/ip/prim/prim_dom_and_2share.core` | `lowrisc:prim:xor2`, `lowrisc:prim:flop_en` |
| `hw/ip/tlul/tlul_lc_gate.core` | `lowrisc:tlul:socket_1n`, `lowrisc:prim:sec_anchor` |

The `prim_mubi` omission prevented FuseSoC from generating the generic
`prim_flop_2sync` module used by its synchronizers. The register-top cores
declared only package dependencies, leaving register-check, TL-UL, and
subregister modules out of their source lists. The masking primitive omitted
its XOR and enabled-flop abstractions, and the lifecycle gate omitted the
TL-UL error responder and secure-anchor primitive. `prim_ram_1p_adv.sv` imports
`prim_mubi_pkg` without a core dependency, which allowed FuseSoC to place the
package after its consumer in the generated source list.

## Focused result

The matrix driver's self-test passed. Targeted reruns with the overlays passed
all seven affected RTL rows and the affected SVA row:

| Lane | Core | Result |
|---|---|---|
| RTL | `lowrisc:ip:lc_ctrl_pkg:0.1` | PASS |
| RTL | `lowrisc:ip:otp_ctrl_pkg:1.0` | PASS |
| RTL | `lowrisc:tlul:trans_intg:0.1` | PASS |
| RTL | `lowrisc:ip:flash_ctrl_prim_reg_top:1.0` | PASS |
| RTL | `lowrisc:ip:otp_ctrl_prim_reg_top:1.0` | PASS |
| RTL | `lowrisc:prim:prim_dom_and_2share:0.1` | PASS |
| RTL | `lowrisc:tlul:lc_gate:0.1` | PASS |
| SVA | `lowrisc:prim:prim_dom_and_2share:0.1` | PASS |

## Follow-up: advanced RAM package ordering

A later corpus snapshot exposed that `prim_ram_1p_adv.sv` imports
`prim_mubi_pkg` while its core declared only the `ram_1p` dependency. Adding the
missing edge removed the unknown-package compile errors in seven affected RTL
rows. The follow-up is **6 PASS, 1 DEBT**. FuseSoC C/C++ file-type notices
remain in setup logs, but all seven warned files were confirmed absent from
their Icarus source lists and are recorded as benign. The `rom_ctrl`
process-synthesis notice remains actionable debt.

| Core | Result after dependency overlay | Remaining diagnostic |
|---|---|---|
| `lowrisc:ip:i2c:0.1` | PASS | — |
| `lowrisc:ip:otbn:0.1` | PASS | C/C++ notices absent from the Icarus source list |
| `lowrisc:ip:otp_ctrl:1.0` | PASS | — |
| `lowrisc:ip:rom_ctrl:0.1` | DEBT | `prim_util_memload.svh:57`, process not synthesized |
| `lowrisc:ip:rv_core_ibex:0.1` | PASS | C/C++ notices absent from the Icarus source list |
| `lowrisc:ip:sram_ctrl:0.1` | PASS | C/C++ notices absent from the Icarus source list |
| `lowrisc:ip:usbdev:0.1` | PASS | — |

The [7-row result JSON](advanced-ram-followup-result.json) retains the setup
warnings, actionable warnings, and verified benign diagnostics.

The tested OpenTitan source snapshot has no Git metadata; its matrix report
records `revision=unknown` and a dirty source state. The overlay and source
SHA-256 fingerprints recorded by that report are:

| Source core | Source SHA-256 | Overlay SHA-256 |
|---|---|---|
| `hw/ip/prim/prim_mubi.core` | `8760c7af65f75ccd03cede48f22e110a116c40f6f7516017e8ea05a8cb0608cf` | `9d30aaeacde9beb2e58a3d7395e34101af55d0fde827798835d18638d62c77df` |
| `hw/ip/prim/prim_ram_1p_adv.core` | `3a9ba165765c3cf570fb3bbc8597df0976d6fb99d621655d7f67877b654dc15e` | `74d5b00aed420a40c7d9fa1e14a1f1ec25513693e15aae0fb3cbc9e5bf518255` |
| `hw/top_earlgrey/ip_autogen/flash_ctrl/flash_ctrl_prim_reg_top.core` | `ffcc9454268f57356ccae63bf988a16c80eea40cee0aef6c75feff0116821849` | `5857645cdfe0f8840f382096956782b49f9f8ec6eb667f92132a217c0b1e427d` |
| `hw/ip/otp_ctrl/otp_ctrl_prim_reg_top.core` | `34ff856cef2f658bff1a6fc86c4bea068979feb97c900286fc8284e25865bafb` | `1c07622516c3e0e62047b4bc1613845f68fcd8e9b1926464da77330eed19681e` |
| `hw/ip/prim/prim_dom_and_2share.core` | `1e592c0c255c560d23be80bd13899db5622e11efc9625e12f314c56530dfc481` | `3242e56a35571810c0d03e3f3e7b1ab05efabb9ac35a90871dc55edcfba18d9b` |
| `hw/ip/tlul/tlul_lc_gate.core` | `01299574f25688e4def59efe0a1eba062a5337911e871cbd954e3001fcf3d425` | `fd590d28905fb76edafea9d19e062fbc93ce0dd8266f30d7a440cf2bc32e170e` |

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
  --lane rtl --lane sva \
  --core lowrisc:ip:lc_ctrl_pkg:0.1 \
  --core lowrisc:ip:otp_ctrl_pkg:1.0 \
  --core lowrisc:tlul:trans_intg:0.1 \
  --core lowrisc:ip:flash_ctrl_prim_reg_top:1.0 \
  --core lowrisc:ip:otp_ctrl_prim_reg_top:1.0 \
  --core lowrisc:prim:prim_dom_and_2share:0.1 \
  --core lowrisc:tlul:lc_gate:0.1 \
  --jobs 1
```

The runner records the source and generated overlay hashes in the result JSON
under `metadata.matrix_source_core_overrides`.

To reproduce the advanced-RAM source-order check, select its affected cores:

```sh
"$OT_PY" scripts/opentitan_matrix.py \
  --opentitan-root /path/to/opentitan-source \
  --build-root /path/to/build/ram-1p-adv-dependency \
  --iverilog /path/to/iverilog/bin/iverilog \
  --fusesoc "$OT_FUSESOC" --fusesoc-python "$OT_PY" \
  --lane rtl \
  --core lowrisc:ip:i2c:0.1 \
  --core lowrisc:ip:otbn:0.1 \
  --core lowrisc:ip:otp_ctrl:1.0 \
  --core lowrisc:ip:rom_ctrl:0.1 \
  --core lowrisc:ip:rv_core_ibex:0.1 \
  --core lowrisc:ip:sram_ctrl:0.1 \
  --core lowrisc:ip:usbdev:0.1 \
  --jobs 1
```
