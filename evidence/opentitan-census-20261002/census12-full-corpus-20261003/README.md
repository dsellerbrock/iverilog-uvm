# OpenTitan full runtime census 12

This is the requested fresh run of all 49 configured OpenTitan runtime targets.
The runtime inventory was checked with `scripts/opentitan_matrix.py --lane
runtime --list` before starting: it reports 49 jobs, comprising 35 UVM and 14
directed targets. The full run will follow the dedicated five-hour Flash replay.

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
- Time limits: 600 seconds for setup and compile, 3,000 seconds per runtime.
  The five-hour limit applies to the separate Flash replay only.
- Runtime memory cap: disabled for the corpus, matching census11. The dedicated
  Flash replay uses its separately requested 10,000,000,000-byte RSS cap.
- OpenSSL and libelf flags are resolved through the OpenTitan Python 3.13
  environment's `pkg-config`.

The exact command is in [`run-census12.sh`](run-census12.sh). Native samples are
scheduled for every VVP runtime process that lasts at least 30 seconds, with
additional samples at 180 and 900 seconds. Results and logs will be written to
`result-census12.json`, `result-census12.md`, and `/private/tmp/pi/census12/build`.
The initial sampler can also match an `iverilog` parent waiting for its VVP
child. Profiles are checked for `Process: vvp`, and compiler-wait captures are
excluded from [`HOTPATHS.md`](HOTPATHS.md). The sampler source now filters to
the VVP executable; the already-running sampler is verified by profile identity.

## Previous coherent census

Census11 recorded 38 PASS, 7 DEBT, 1 compile FAIL, 2 RUNTIME_FAIL, and 1
RUNTIME_TIMEOUT across 49 targets. The 5-hour Flash replay is a separate
focused result and does not replace the full matrix's Flash row.
