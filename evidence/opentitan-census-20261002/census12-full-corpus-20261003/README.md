# OpenTitan full runtime census 12

This is the requested fresh run of all 49 configured OpenTitan runtime targets.
The runtime inventory was checked with `scripts/opentitan_matrix.py --lane
runtime --list` before starting: it reports 49 jobs, comprising 35 UVM and 14
directed targets. The full run will follow the dedicated five-hour Flash replay.

## Run configuration

- OpenTitan source: `/private/tmp/ot-corpus-after-fixes-20260929/source`, pinned
  revision `a78922f14a8cc20c7ee569f322a04626f2ac6127`, with the existing
  compatibility overlay edits.
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

The exact command is in [`run-census12.sh`](run-census12.sh). Results and logs
will be written to `result-census12.json`, `result-census12.md`, and
`/private/tmp/pi/census12/build`.

## Previous coherent census

Census11 recorded 38 PASS, 7 DEBT, 1 compile FAIL, 2 RUNTIME_FAIL, and 1
RUNTIME_TIMEOUT across 49 targets. The 5-hour Flash replay is a separate
focused result and does not replace the full matrix's Flash row.
