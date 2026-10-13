# SV-Tests corpus run evidence — 2026-10-13

## Corrected source-build run

- Slurm job: 816 on DAN-DESKTOP.
- Icarus source commit: db458c438eca253fb1b3110f671fe3800e33b7a0.
- Icarus source tree: 2cb6260f02c1680196cca51d76e6e429e3b738d5.
- Icarus binary SHA-256: be07507e40469183634d4773e68af00d76aeac6147eaecfdf8f4381d573f26b7.
- VVP binary SHA-256: 9318dbe5d0f019c95235df400a9da60ca84f4d41b3493f8684fd1cf3f753fa75.
- sv-tests commit: c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7.
- sv-tests archive SHA-256: 3924ac0ef31a1cd3d39bb6942b4b313b690468f9ae296210f6e9e3093b640ac5.
- UVM commit: 656f20d087370a7c742e00188d20bbf30fa95339.
- Environment: Ubuntu on DAN-DESKTOP, GCC 15.2.0, Python 3.14.4.
- Runner explicitly checked that iverilog and vvp resolved to wrappers for this build.
- Result: 1,027 applicable, 1,022 runner-passed, 5 runner-failed. See corrected-run/summary.json.
- Corrected per-test raw-log archive: corrected-run/raw-logs.tar.gz, SHA-256 3555d678a47caa892791d6587aaec2647c1db77c419ff31131becf68eaf5a954. It contains all 1,027 Icarus logs and an embedded per-file checksum manifest.

The scripts and run log are in corrected-run/. The evidence is sufficient to reproduce how the suite was launched and to inspect each test result. The runner’s result classes do not imply that every accepted test received semantic checking. The historical 424-row Icarus 12.0 classification and corrected-source crosswalk are in [the docs CSV](../../docs/conformance/sv_tests_gap_2026-10-13_historical_424.csv).

## UVM DPI follow-up

The 37 UVM cases initially lacked `uvm_dpi.vpi`. A focused local rerun loaded the module for every case; its per-case results, environment, runtime evidence, and raw logs are in [uvm-dpi-followup](uvm-dpi-followup/README.md). The rerun found no confirmed simulator defect in this group.

## Event-control follow-up

Slurm job 822 compiled and ran event-trigger-after-waiter-ready.sv using the same Icarus install. The trigger was delayed until after the event waiter had started; the log records the expected assertion and vvp_rc=0. Its job output and simulator log are in corrected-run/event-trigger-control-822/. Slurm accounting is unavailable, so the terminal scheduler state is not independently recorded.

## Superseded original run

Slurm job 792’s original-run-792/ logs and root-level raw-failing-logs.tar.gz are retained for audit, not feature ranking. Although job 792 built the source tree above and recorded binary SHA-256 b0b618fd7982b520347be3f78154fd5c146a92e72952b30659661a1ff911d1bd, its suite runner resolved /usr/bin/iverilog instead of that build. The effective simulator was Icarus 12.0, SHA-256 a6681e0b577dcfc4ea83d1591a5714710b0b3535ebb36491ee8177553bab9631. The 603/1,027 result and 424 logs therefore do not describe the source-built Icarus run. See [the runner-path investigation](runner-path-investigation.md) and the corrected [classification report](../../docs/conformance/sv_tests_gap_2026-10-13.md).
