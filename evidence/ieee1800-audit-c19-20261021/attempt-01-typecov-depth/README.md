# IEEE 1800 §19.8 type-coverage depth probes

Six separate cases exercise covergroup and coverpoint `get_coverage()` through type scope (`::`) and instance handles (`.`), plus instance `get_inst_coverage()` and two-argument type/instance forms. Each case uses two instances with bins `{0,1}` and `{1,2}` sampled; `type_option.merge_instances=1` makes the expected type union 3/4 = 75%, while each instance is 2/4 = 50%. Inputs are also retained under `input/` and as standalone audit tests in `tests/1800_audit/c19/`.

## Standard basis

- IEEE 1800-2017 §19.7 Table 19-1 (p. 579): `get_inst_coverage` “Only applies when the merge_instances type option is set.” §19.8 Table 19-5 (p. 582) permits `get_coverage` on covergroup and coverpoint; §19.8 says it is static and available on both types via `::` and instances via `.`. §19.11.3 (pp. 588–589) says merged type coverage is “a union of coverage of all instances.”
- IEEE 1800-2023 §19.7 Table 19-1 (p. 606), §19.8 Table 19-5 (pp. 610–611), and §19.11.3 (pp. 616–617) state the corresponding requirements.

Each probe was run under both `-g2017` and `-g2023`, using a 60-second timeout for each compile and simulation. Raw logs, return codes, commands, and SHA-256 hashes are retained here.
