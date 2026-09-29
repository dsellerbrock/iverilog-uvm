# Guarded Caliptra TRNG selected replay — 2026-09-29

The original-cadence `smoke_test_trng` passed with `-gcommercial-unsafe` and the named reset, pure-checker, and ephemeral-JTAG copied-source overlays. Pinned Caliptra and Adams Bridge sources remained clean. This is one selected diagnostic pass outside the historical 52-case aggregate.

The run used a 16-hour timeout and 8-GiB physical-footprint cap. VVP exited 0 with one pass marker, zero failure markers or bad diagnostics, no timeout or cap hit, and a peak footprint of 1,282,671,936 bytes. Firmware retired 34,230 instructions in 138,353 cycles. Entropy boot completed at 1,060,710 ns; both 512-bit CSRNG Generate commands returned four checked blocks and their final status polls returned 0x6.

`result.json` records the case verdict and copied-source provenance. `summary.json` records compiler/runtime fingerprints and before/after source integrity. The prior 52-case census remains 20 pass, 16 four-hour timeout, 3 assertion failure, 2 low-swap kills, and 11 unfinished; this selected result does not change that denominator.
