# SPI Device scope-randomize queue reducer

Minimal synthetic reducer for released OpenTitan Earlgrey-PROD-M6
`spi_device_tpm_base_vseq.sv`'s `bit [7:0] byte_q[$]` and
`std::randomize(byte_q) with { byte_q.size() == exp_num_bytes; }` call.

`reducer.sv` specifies successful resize to a positive count and zero,
then specifies transactional failure: contradictory size constraints return
0 and preserve the previous size and byte values. It was RED before the
exact-size local-queue implementation and now prints `PASS` on the focused
candidate. The unchanged released SPI Device compile still fails on later
aggregate expressions; neither full standards nor DV qualification follows.

Baseline command from the campaign worktree:

```sh
local-install/bin/iverilog -g2017 -o /tmp/ot-spi-std-randomize-queue.vvp evidence/ot-spi-std-randomize-queue-20260923/reducer.sv
local-install/bin/vvp /tmp/ot-spi-std-randomize-queue.vvp
```

The [revision-scoped result](../../docs/conformance/session_logs/2026-09-23_scope_queue_randomize_focus.json)
links the focused checks and the pinned SPI Device compile log.
