# Xilinx board-top scope review

The project decision is to leave board-level Xilinx primitive handling to
Vivado. These three rows are therefore excluded from Icarus qualification and
recorded as `OUT_OF_SCOPE`; they are not reported as compiler passes.

| Core | Icarus blockers in the original compile | Disposition |
|---|---|---|
| `lowrisc:systems:chip_earlgrey_cw310:0.1` | `BUFG`, `USR_ACCESSE2` | `OUT_OF_SCOPE` |
| `lowrisc:systems:chip_earlgrey_cw310_hyperdebug:0.1` | `BUFG`, `USR_ACCESSE2` | `OUT_OF_SCOPE` |
| `lowrisc:systems:chip_earlgrey_cw340:0.1` | `MMCME2_ADV`, `BUFG`, `USR_ACCESSE2` | `OUT_OF_SCOPE` |

The [focused runner result](result.json) applies that policy without invoking
FuseSoC or Icarus for these three rows. The [scope-reviewed aggregate](../result-scoped-aggregate.md)
keeps the original 309-row inventory visible. It now has four out-of-scope rows
because the EnglishBreakfast CW305 board target shares the same policy.

## UNISIM check

I fetched Xilinx's public [XilinxUnisimLibrary](https://github.com/Xilinx/XilinxUnisimLibrary)
at commit `1c8e05fd1e9a79ceb8b996a0996674122eed086f`. Its README identifies the
Verilog models as Apache-2.0 and corresponding to Vivado 2020.1; it contains all
three primitive files. The first probe listed `glbl.v` as a source but did not
select `glbl` as an elaboration root, so it left the MMCM's `glbl.GSR` and
`glbl.PLL_LOCKG` references unresolved. The corrected replay uses both
`-s <board-top>` and `-s glbl`, plus `-y <unisims-dir>`; that resolves all
Xilinx primitive and `glbl` errors. Results and full logs are in
[the corrected replay result](unisim-glbl-root-replay-20261006/result.json).

The three EarlGrey board tops still exit 7 on the same seven
`otbn_rf_bignum_fpga.sv:82` multiple-driver diagnostics. The EnglishBreakfast
CW305 top resolves its four missing Xilinx primitive errors but exits 1 on a
separate `ast` instance port mismatch (`clk_osc_byp_i`). These are outside the
UNISIM library; the census continues to exclude board targets under the
project's Vivado-handled policy.

AMD's [simulation guide](https://docs.amd.com/r/en-US/ug900-vivado-logic-simulation/Simulating-with-Third-Party-Simulators)
lists ModelSim, Questa, Xcelium, VCS, Active HDL, and Riviera PRO for
third-party simulation; Icarus is not in that list. The library removes the
primitive-binding blockers but does not produce clean board-top compiles for
the remaining source diagnostics above. The three EarlGrey rows remain
explicitly excluded under the project decision.
