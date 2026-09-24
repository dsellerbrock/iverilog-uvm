# Pinned CSRNG width overlay replay

The patch applies cleanly with `patch --dry-run -p1` and `patch -p1` to a
disposable copy of Earlgrey-PROD-M6 revision
`a78922f14a8cc20c7ee569f322a04626f2ac6127`. The pristine
`hw/ip/csrng/dv/tb.sv` SHA-256 is unchanged at
`57cd498fa284ce107553050c17bbca22797030c30e643b2e3562877e5742ff52`.
The only source changes are one `tb`-local 128-bit width constant and its use
in the two CSRNG `-:` width operands. The assertion expressions and their
hierarchical base operands remain intact.

The actual released CSRNG FuseSoC filelist compiles with the installed Icarus
compiler, `-g2017 -gcommercial-unsafe -uvm`, pinned UVM 1.2, the UVM/DUT
defines, and `csrng_cov_bind` selected as a root: exit 0, zero errors, 20
warnings. This is a compile advance only. In particular, the log still says
the CSRNG monitor event was skipped at `csrng_monitor.sv:115` (with a
false-branch fallback at line 116), and a constraint item was ignored.

A separate fresh FuseSoC setup from the same pinned release selected DVSIM's
`csrng_smoke` (`+UVM_TESTNAME=csrng_smoke_test` and
`+UVM_TEST_SEQ=csrng_smoke_vseq`). The selected six runtime plusargs are
preserved exactly. This patched image compiled with all six bind roots and
`+timescale+1ns/1ps`: exit 0, zero errors, 33 warnings. The configured VVP
run aborted in 1.216 s with process return code -6, before any UVM report:
`Assertion failed: (vsig), function get_word_size, file array.cc, line 483.`
There is no pass banner or CSRNG DV verdict. This is the next runtime blocker;
no follow-up source change was attempted. [smoke-replay.json](smoke-replay.json)
holds the exact setup/compile/run commands, tool SHA-256 fingerprints, and
return codes; the adjacent `smoke-*.log.gz` files preserve raw output.

[replay.json](replay.json) contains the exact dry-run, application, and
compiler commands, exit codes, source hashes, and raw log names. Paired
2017/2023 controls are in [controls.json](controls.json): the strict
instance-hierarchical width reducer still fails to compile (exit 2), while
the local constant width control compiles and runs successfully (exit 0).
The legality analysis is in the earlier [triage finding](../opentitan-csrng-blklen-triage-20260923/FINDING.md).
