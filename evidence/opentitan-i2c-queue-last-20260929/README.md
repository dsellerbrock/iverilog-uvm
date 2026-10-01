# OpenTitan I2C queue-last elaboration — 2026-09-29

The selected I2C compile rejected three legal queue `[$]` accesses through class properties. The elaborator now handles a queue property write, a queue-of-class root read, and a nested queue-of-class property write. Paired 2017/2023 positive and negative regressions cover the supported accesses, empty queues, and a fail-closed indexed-receiver case that would otherwise evaluate an index expression twice.

On the same pinned OpenTitan source and installed compiler image, selected `i2c_sim` hard diagnostics fall from 18 to 15; none of the three queue errors remains. The remaining hard errors are three coverage-bin limitations, one `std::randomize` dynamic-array constraint, and eleven random-dependent constraint-function calls. Eleven semantic notices also remain. **I2C DV still fails compilation.** `result.json` and `compile.log.gz` preserve the exact current verdict and diagnostics. Caliptra was not run.
