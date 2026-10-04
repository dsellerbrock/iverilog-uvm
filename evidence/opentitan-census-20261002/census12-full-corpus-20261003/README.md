# OpenTitan full runtime census 12

This records the requested fresh run of all 49 configured OpenTitan runtime
targets and its later focused retries. The runtime inventory was checked with
`scripts/opentitan_matrix.py --lane runtime --list` before starting: it reports
49 jobs, comprising 35 UVM and 14 directed targets. The original full-matrix
result is preserved; [`result-census12-updated.md`](result-census12-updated.md)
combines it with the later OTBN, OTP, and five-hour Flash retries.

## Run configuration

- OpenTitan source: `/private/tmp/ot-corpus-current-spid-passthrough-20261003/source`,
  based on pinned revision `a78922f14a8cc20c7ee569f322a04626f2ac6127`, with the
  existing compatibility overlay edits. The earlier source copy had a dangling
  `top_englishbreakfast/top_pkg.core` symlink, so the validated complete copy is
  used for this run.
- Compiler wrapper: `/private/tmp/current-tools/bin/iverilog`; its VVP runtime
  resolves to this worktree's `vvp/vvp` executable.
- UVM: the pinned UVM 1.2 source tree used by census11.
- Profile: `--lane runtime --commercial-unsafe --jobs 2`.
- Initial matrix time limits: 600 seconds for setup and compile, 3,000 seconds
  per runtime. The exact-default Flash retry used an 18,000-second timeout.
- Runtime memory cap: disabled for the corpus, matching census11. The dedicated
  exact-default Flash retry used a 9,536 MiB cap, within the requested 10 GB
  budget.
- OpenSSL and libelf flags are resolved through the OpenTitan Python 3.13
  environment's `pkg-config`.

The exact command is in [`run-census12.sh`](run-census12.sh). Native samples are
scheduled for every VVP runtime process that lasts at least 30 seconds, with
additional samples at 180 and 900 seconds. Initial full-matrix results are in
`result-census12.json` and `result-census12.md`; the composite census is in
`result-census12-updated.json` and `result-census12-updated.md`. Full-matrix
logs are under `/private/tmp/pi/census12/build`, with focused retry logs under
`/private/tmp/pi/census12`.
The initial sampler can also match an `iverilog` parent waiting for its VVP
child. Profiles are checked for `Process: vvp`, and compiler-wait captures are
excluded from [`HOTPATHS.md`](HOTPATHS.md). The sampler source now filters to
the VVP executable; the already-running sampler is verified by profile identity.

## Previous coherent census

Census11 recorded 38 PASS, 7 DEBT, 1 compile FAIL, 2 RUNTIME_FAIL, and 1
RUNTIME_TIMEOUT across 49 targets. The 5-hour Flash replay is a separate
focused result and does not replace the full matrix's Flash row.

## OpenTitan compatibility overlays

The final retry results use the pinned OpenTitan source copy with explicit
compatibility patches. These patches live under `compat-patches/` and can be
applied to a clean source tree at the revision recorded above. Set `PATCH_DIR`
to this directory and `OPENTITAN_ROOT` to that source tree, then run:

[OTP cleanup](compat-patches/otp-get-offset-covergroup-purity.patch),
[Flash solve ordering](compat-patches/flash-elementwise-solve-before.patch),
and [SPI-TPM SRAM/reset adaptation](compat-patches/spi-tpm-sram-csb-reset.patch).

```sh
patch -p1 -d "$OPENTITAN_ROOT" < "$PATCH_DIR/otp-get-offset-covergroup-purity.patch"
patch -p1 -d "$OPENTITAN_ROOT" < "$PATCH_DIR/flash-elementwise-solve-before.patch"
patch -p1 -d "$OPENTITAN_ROOT" < "$PATCH_DIR/spi-tpm-sram-csb-reset.patch"
```

The Flash patch expands solve ordering over Earlgrey's 26 packed info-page
queue entries, removing the unsupported aggregate ordering while preserving
the specified order. The SPI-TPM patch adapts the legacy pre-DV testbench to
the current SRAM-backed DUT and models the chip-select-derived resets needed
between transactions. Its completion marker is accepted only when the host
transaction completion and pass banners appear without the timeout banner.
