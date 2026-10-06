# Candidate OTP control result

The latest rebuilt compiler engine (SHA-256
`367e44671b5aabf7786a200c2af4c3dcbd17c449bffa3ea2bc30fbfcfbaa1abc`) passes
OpenTitan `lowrisc:dv:otp_ctrl_sim:0.1` on the reproducible census18 patched
source with zero hard errors and zero semantic debt. The [row result](result.md),
[JSON](result.json), compile log, and guard log preserve the evidence.

The source is pinned OpenTitan commit
`a78922f14a8cc20c7ee569f322a04626f2ac6127` plus the
[consolidated overlay](../candidate-census18-pinned-compile-20261005/source-overlay.patch)
and [Trial1 relocation helper](../../../docs/conformance/release_overlays/opentitan/trial1_core_layout_overlay.py).
The OTP overlay types the timeout bound and keeps random force values in stable
banks. The [clean-source recheck](clean-source-recheck/README.md) still fails on
15 procedural-force diagnostics and has 36 coverage-constructor purity notices,
but no longer reports the unbased-fill range endpoint error.

The direct language fix and controls are registered in both regression lists.
All six focused 2017/2023 tests pass under both harnesses; the compact outputs
and legacy compile logs are in [focused regressions](focused-regressions/).
This one-row overlay result does not qualify the clean source or the full
OpenTitan corpus.
