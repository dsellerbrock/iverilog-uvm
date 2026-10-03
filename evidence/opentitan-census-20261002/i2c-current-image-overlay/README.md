# I2C current-image replay

`lowrisc:dv:i2c_sim:0.1` passes on the current Icarus image with zero hard compile errors, semantic debt, runtime errors, or runtime debt. The compile command includes `-gcommercial-unsafe`. Runtime completed in 756.713 seconds; the 4 GiB physical-footprint guard recorded 651,182,992 bytes.

The [I2C warning cleanup patch](../../../docs/conformance/release_overlays/opentitan/i2c_runtime_warning_cleanup.patch) was applied after the four existing I2C overlays on a disposable source copy based on census11 revision `a78922f14a8cc20c7ee569f322a04626f2ac6127`. It moves coverage-object construction into the existing `en_cov` branch, explicitly discards `pop_back()`'s unused result, and removes the invalid `solve before` clause on `cfg.clk_freq_mhz`; all frequency-based `speed_mode` constraints remain.

`clk_freq_mhz` is declared `rand` in `dv_base_env_cfg`, but `i2c_host_perf_vseq` inherits `cfg` as a non-`rand` handle from `dv_base_vseq`. The config object is therefore outside the sequence's active random-object set, so its field is state during `sequence.randomize()`. IEEE 1800-2017's active-object and variable-ordering rules (§18.5.9 and §18.5.10) and IEEE 1800-2023's corresponding rules (§18.5.8 and §18.5.9) support the correction. The registered paired strict control passes 4/4 in both the [JSON and legacy focused regressions](external-handle-solve-before/README.md). Its positive control keeps the external frequency fixed and enforces the mode constraints; its negative control fails closed when the invalid ordering is present. The source preimage and patched SHA-256 values are recorded below:

| File | Before | After |
| --- | --- | --- |
| `hw/ip/i2c/dv/sva/i2c_protocol_cov.sv` | `d517b297226819233253bfe7ff9982c27bba2a97ff4759362bce5732b28d1611` | `7acaf1466513f2fd8f28b31261b0d78f9d5e388bdb0ee73f5ce883e2030ef2fa` |
| `hw/dv/sv/i2c_agent/i2c_if.sv` | `9d27370ef1612a09cdc9e75e4b2c7d9eca22c5b310573a42a8c64b713d8579f8` | `c9a24cfa67030cb6defb6fed64528f019ca5885d34adb324681762b04a40b34e` |
| `hw/ip/i2c/dv/env/seq_lib/i2c_host_perf_vseq.sv` | `29802640c4558ce3eea87e6818a1b2e1b2ad36839b500d39c5de39089c09c3a8` | `c22bd8423b64065942b43f39a924389b9f665dc30ce7a1cff3d8c7999bea3f9f` |

The [result JSON](result.json) records fingerprints, exact commands, and status. The [setup](matrix-setup.log), [compile](matrix-compile.log), [runtime](matrix-runtime.log), and [compiler source list](matrix-iverilog.scr) are preserved beside it. The full 49-row census has not been rerun.
