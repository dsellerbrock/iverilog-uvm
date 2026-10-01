# SPI Device JEDEC selected check — 2026-09-29

The pinned OpenTitan pre-DV JEDEC case compiles on the installed DD-089 compiler with `-g2012 -gcommercial-unsafe` after three named patches are applied to a disposable source copy. The first two repair the released testbench's stale command-info and port interfaces. The third patch, [spid_jedec_fatal_checks.patch](../../docs/conformance/release_overlays/opentitan/spid_jedec_fatal_checks.patch), makes its timeout fatal and requires exactly five continuous-code bytes and JEDEC ID `BEA55A`.

The selected compile exited 0 with zero warnings or hard diagnostics. The guarded runtime exited 0, printed the received manufacturer `BE` and device ID `A55A`, reached the single checked completion marker, and reported no bad diagnostics, timeout, or memory-cap hit. The 6-GiB guard did not sample a peak footprint because this case finished in under one second.

`source-provenance.json` verifies pinned source Git objects, patch hashes, and copied-source hashes. `compile-result.json` and `runtime-result.json` preserve the selected image, outcome, and raw runtime-log hash. The raw log remains in the projectless work directory. This is a copied-source, opt-in compatibility check; the historical 49-case OpenTitan census is unchanged.
