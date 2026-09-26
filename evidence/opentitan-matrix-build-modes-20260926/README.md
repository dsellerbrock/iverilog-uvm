# OpenTitan matrix with dvsim build modes applied

This matrix isolates the effect of the harness change on `agent/ot-matrix-build-modes-20260926`. The compiler is main `4c45450a4`: the same locked baseline build as `evidence/opentitan-main-census-4c45450a4` in #387, with `lib/ivl/ivl` `3fb64d55…` and `bin/vvp` `99eaa1d6…`. Only `scripts/opentitan_matrix.py` differs. Like every UVM compile in this campaign, it is nonstandard compatibility evidence under `-gcommercial-unsafe`.

Inputs: OpenTitan Earlgrey-PROD-M6 `a78922f14a8cc20c7ee569f322a04626f2ac6127` (`clean-corpora/opentitan-7a3ad34`, verified at the pin), UVM 1.2, and FuseSoC `ot-0.5.dev0`, run with `--lane runtime --commercial-unsafe --jobs 2`.

## Result

| | #387 baseline | With build modes |
| --- | --- | --- |
| DEBT (runtime pass with degradation warnings) | 9 | 9 |
| RUNTIME_FAIL | 6 | **8** |
| FAIL (compile) | 34 | **32** |

| Core | Before | After | Why |
| --- | --- | --- | --- |
| kmac | FAIL: `kmac_if.sv` syntax error | compiles; smoke fails at `randomize()` | `kmac_masked_sim_cfg`'s `enable_mask_mode` now defines `EN_MASKING=1` and `SW_KEY_MASKED=0` |
| rom_ctrl | FAIL: `rom_ctrl_env_pkg.sv:37` syntax error | compiles; runtime fail | build-mode defines such as `ROM_BYTE_ADDR_WIDTH` now reach the compile |
| sram_ctrl | FAIL: `` if (`INSTR_EXEC) `` syntax error | FAIL: a later, genuine parser gap, `pkg::f(.a(x)).m();` | `INSTR_EXEC` and `SRAM_ADDR_WIDTH` are now defined |
| aes, flash_ctrl, spi_device, lc_ctrl | — | same status | a runnable variant cfg is now selected instead of an imported base cfg |

No core regressed. lc_ctrl's smoke still passes under `lc_ctrl_volatile_unlock_disabled_sim_cfg`, which defines `SEC_VOLATILE_RAW_UNLOCK_EN=0`, the value the per-core fallback used to hardcode.

`result.md` and `result.json` hold the full table, and `run.log` is the matrix console log.
