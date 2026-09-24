# Strict Caliptra L0 compile guard after P1

The pinned `smoke_test_veer` top was submitted to the current installed Icarus
compiler in strict `-g2017 -gassertions` mode, without
`-gcommercial-unsafe` or source overlays. The compile exited 46: all 46
errors reject continuous/procedural overlap in bundled
`caliptra_top_tb_axi_complex.sv`. There were no other compiler errors and no
Preponed sampling warnings. No runtime ran; the released L0 count is 0/52
attempted in this strict guard, with all 52 unrun.

`compile.command.json` records the exact command and tool/profile SHA-256
fingerprints. The runner, installed compiler/ivl/vvp target/vvp, and profile
hashes matched those fingerprints after the compile. `summary.json` confirms
both pinned source checkouts remained clean at their expected commits.

This is an IEEE strict-mode rejection guard, not a Caliptra L0 pass or a
commercial-unsafe compatibility result.
