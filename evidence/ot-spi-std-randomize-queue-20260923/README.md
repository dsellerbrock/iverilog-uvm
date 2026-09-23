# SPI Device scope-randomize queue reducer (RED)

Minimal synthetic reducer for released OpenTitan Earlgrey-PROD-M6
`spi_device_tpm_base_vseq.sv`'s `bit [7:0] byte_q[$]` and
`std::randomize(byte_q) with { byte_q.size() == exp_num_bytes; }` call.

`reducer.sv` specifies successful resize to a positive count and zero,
then specifies transactional failure: contradictory size constraints return
0 and preserve the previous size and byte values. This is a reducer/spec only;
it does not claim the current compiler reaches runtime, standards qualification,
or an OpenTitan DV pass.

Baseline command from the campaign worktree:

```sh
local-install/bin/iverilog -g2017 -o /tmp/ot-spi-std-randomize-queue.vvp evidence/ot-spi-std-randomize-queue-20260923/reducer.sv
```
