# Caliptra Icarus copied-top first case

`smoke_test_veer` completed **1/1 diagnostic pass**, with 51 selected cases unrun in this invocation. The runner used the bundled Caliptra BFM, explicit `-gcommercial-unsafe`, and hash-guarded disposable reset, pure-checker, and ephemeral JTAG-port copies. The pinned testbench's one `ListenPort` setting changed from `63224` to `0` only in the copied top so independent VVP processes can bind their JTAG server. This is nonstandard compatibility evidence, not IEEE conformance or a pristine-source L0 pass.

The firmware and VVP exited zero. The runtime recorded one pass marker, zero fail markers, zero error/assertion, missing-DPI, or JTAG-server diagnostics, 633 retired instructions, 4,348 cycles, and 634 trace commits. Pinned sources stayed clean; source and tool fingerprints matched before and after. See `summary.json`, `compile.command.json`, and `smoke_test_veer/result.json` for the complete checks. The exact command was:

```sh
python3 evidence/caliptra-icarus-l0-runner-20260923/run.py \
  --commercial-unsafe --reset-overlay --checker-source-overlay \
  --ephemeral-jtag-port --case smoke_test_veer --timeout 1800 \
  --output evidence/caliptra-icarus-l0-ephemeral-jtag-first-20260924
```
