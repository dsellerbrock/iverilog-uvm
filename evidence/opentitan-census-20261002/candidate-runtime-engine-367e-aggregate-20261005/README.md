# OpenTitan candidate runtime recheck — engine 367e

**49/49 selected runtime targets PASS.** The aggregate covers the canonical 35 UVM and 14 directed targets, once each and in inventory order. Every row has a pass banner and zero hard errors, semantic/runtime debt, timeout, or memory-limit hit.

The serial full run completed 48 targets and stopped at I2C during source-overlay staging. The pinned source snapshot already contained the exact hash-checked I2C overlay, so staging rejected it before compile or simulation. After making I2C overlay staging idempotent, a focused I2C replay passed. The aggregate replaces only that staging-failure row; both raw reports are preserved below.

## Run identity

- Engine SHA-256: `367e44671b5aabf7786a200c2af4c3dcbd17c449bffa3ea2bc30fbfcfbaa1abc`
- OpenTitan input: the same reconstructed source snapshot in both runs; see the [pinned overlay provenance](../candidate-census18-pinned-compile-20261005/README.md#reproducible-source-overlay)
- UVM: 1.2; compile profile: `commercial-unsafe`; serial (`--jobs 1`)
- Per-target runtime timeout: 18,000 seconds; process memory cap: 9,536 MiB
- Focused I2C runtime: 1134.878 seconds; peak footprint 646.3 MiB

The 48-row full-run report remains [`candidate-runtime-engine-367e-20261005`](../candidate-runtime-engine-367e-20261005/result.json) (48 PASS, 1 `SOURCE_OVERLAY_FAIL`). The one-row replay is [`candidate-runtime-engine-367e-i2c-resume-20261005`](../candidate-runtime-engine-367e-i2c-resume-20261005/result.json). Its original setup, compile, and runtime logs are gzip-archived in [`logs/`](logs/); use `gzip -dc <file.gz>` to read them.

See [`result.json`](result.json) for the combined rows and [`result.md`](result.md) for the target table. The broader 309-row compile census remains mixed; this closes the selected 49-target runtime gate on engine 367e, not every OpenTitan compile row. See the [compile census](../candidate-engine-367e-compile-census-20261005/README.md).
