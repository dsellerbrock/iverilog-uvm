# I2C external-handle solve-before control

The paired strict control distinguishes a `rand` field in an external config object from a random variable in the sequence being randomized. `dv_base_vseq` contains `CFG_T cfg;` without a `rand` modifier; `dv_base_env_cfg` declares `rand uint clk_freq_mhz;`. Because the config handle is not an active random handle in `i2c_host_perf_vseq.randomize()`, the frequency remains state for this solve.

The positive control removes only `solve cfg.clk_freq_mhz before speed_mode;`. It randomizes the sequence at 2, 5, and 8 MHz, checks the original mode bounds, and confirms the external config frequency is unchanged. The negative control adds that ordering to the same frequency constraints and checks that randomization fails closed without changing the external state.

The source rule is in the IEEE 1800-2017 active-object selection and variable-ordering rules (§18.5.9 and §18.5.10) and IEEE 1800-2023 corresponding rules (§18.5.8 and §18.5.9). Both strict editions pass all four registered cases in the JSON regression and the legacy regression. The negative case's expected compile warning and solver error are preserved in the gold output; its self-check passes only when `randomize()` returns failure.

Compiler fingerprints: `iverilog` SHA-256 `53969c0e4a140f0f2accec98b752c4d37529d912ddb255bec0ed5dc9d1a07bcc`, engine `6a18cb3c8c4da86ad3e230935d8085635ea015e9fbf24eb4f6e07a8fd6ed384b`, VVP runtime `215774b9c3f6f3affb0be206afe017554b64b51885516b55d51f9fd57e6cfca1`. The selected OpenTitan I2C replay uses `-gcommercial-unsafe` separately; this focused language control uses strict `-g2017` and `-g2023`.
