# §11.4.13 membership coverage

## Standards and scope

IEEE 1800-2017 and 1800-2023 §11.4.13 specify that nonintegral set members compare with `==`, integral values compare with `==?`, and string ranges are legal. The 2023 text adds absolute `+/-` and relative `+%-` tolerance ranges; the 2017 edition does not include those operators.

Existing `p11_04d_cat_inside_stream_reduced.sv` covers ordinary values, queue-member traversal, integral wildcard/X/Z behavior, `$` bounds, and empty reversed ranges. The added `input/p11_13_nonintegral_inside.sv` checks string equality/range membership and real equality membership.

## Current-head paired results

- Checkout `38182f4ba2e7d17c99ab3ea31add1b8d99c51e36`; Mac ARM64; Icarus/VVP 13.0 devel (`9bd5082b8`), SHA-256 `iverilog` `b92ded447f28bda589f2eac77ea4ec09115687286bb69ada09e3e3a6b14882fc`, `vvp` `22dae2c8cc68f40455ded0f7d66a7a0700f784223b840c4fa3212700c28abc94`.
- The existing §11.4.13 reducer compiles/runs under both `-g2017` and `-g2023`, 22/22 checks each. The new string/real probe compiles/runs under both, 4/4 checks each.
- Existing `ivtest/ivltests/sv_tolerance_range_2023.v` compiles/runs under `-g2023` and prints `PASS`; it exercises absolute/relative tolerance, signed and unsigned values, integral truncation, real tolerance, case-inside, constraints, and coverage bins. It emits the simulator's existing soft-sampling fallback warning for one distribution; this test checks allowed values, not distribution quality.
- Existing `sv_tolerance_range_2017.v` is rejected under `-g2017` with the edition-specific diagnostic that tolerance ranges require 1800-2023, as expected.
- Each compiler and VVP invocation had a 30-second Python timeout under `~/codex-supervisor/localrun 180`. The batch took 3.42 s and peaked at 49,561,600 bytes RSS. Raw per-edition logs and return codes are in `current-head-check/`.

No new gap was found; no issue or comment was posted by A3. The audit lead's previous §11.4.13 `IMPLEMENTED (tested subset)` classification stands; this adds evidence for the nonintegral and edition-specific forms.

Two initial `current-head-check` launches used the wrong top-module selection; their setup-only errors are preserved under `runner-top-error/` and `runner-top-error-2/` and are not behavioral results.
