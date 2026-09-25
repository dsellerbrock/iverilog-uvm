# OpenTitan CSRNG function-output bit copy-back

This branch starts at PR #364 (`91e5499e5`) and changes only Icarus function
output copy-back. The pinned OpenTitan checkout remains clean at
`a78922f14a8cc20c7ee569f322a04626f2ac6127`. The named CSRNG BlkLen
overlay was selected on a disposable source copy. The separate
`backdoor-diagnostic.patch` was applied only to another copied testbench to
trace the first failure; it was absent from the final released replay.

At 1000 ps, before reset, the physical `tb.dut.u_reg.u_ctrl_enable.q` is X.
The four-state `uvm_hdl_read` output carries that X. Its function output
copy-back into two-state `uvm_reg_data_t` retained X, causing the released
`$isunknown(field_val)` check to fail. Native task copy-back and direct
assignment already converted X/Z to zero. The strict 2017 and 2023 baseline
registered reducers each failed their legal output case while both nonlvalue
negatives rejected as expected (2/4 per runner). A further paired width
reducer exposed a direct-store VVP assertion and partial unpacked-array word
write when a narrow formal returned into a wider actual.

The final source pads or truncates the returned value to the actual width,
then applies `%cast2` only for `bit` receivers. The paired legal reducers
cover direct signals, unpacked array elements, class scalar properties,
signed and unsigned width changes, preserved four-state X/Z, and a native
task control. The paired nonlvalue negatives still reject. Final focused
legacy and JSON runners each pass 4/4; `make check` passes. The private tool
SHA-256 values are ivl `b4e5dec66b067e2e74526dbe1b0086de4a4152dc5cfc5126db6920a535a1f408`
and VVP `c6fd0821d294d548f41fbab33792db2d7e582c98cd01dab5d432ee199e929483`.

The final pinned CSRNG compile and native AES DPI build exit zero using
`-g2017 -gcommercial-unsafe`. The runtime completes at 5,537,881 ps but
reports one UVM_FATAL at the first `cs_item.randomize()` and `TEST FAILED
CHECKS`, before meaningful command traffic. Its VVP exit zero is **0/1
released nonstandard compatibility DV**, not a pass. The compiled inline
constraint [captures the freshly created item's properties](next-randomize-bytecode.txt)
as `v:` values rather than constraining its target `clen` property to 12;
that is a separate next blocker.
The unrelated `int_state_read_enable_c` ignored-constraint warning also
remains. [Compile](final-release-compile.json), [native DPI](final-release-dpi.json),
and [runtime](final-release-runtime.json) records contain exact commands,
working directories, durations, and exits; adjacent logs contain output.

The final-image broad legacy gate passes 6,613 total with zero failures,
two not implemented, and three expected failures. Real-DPI UVM passes
358/358 with zero failures or skips and the real DPI umbrella loaded.
The first full JSON attempt failed only two optional FPGA expected-error
tests because this private installation lacked `fpga.conf`/`fpga.tgt`.
Building and installing the existing `tgt-fpga` target into the same private
prefix restores both focused tests (2/2); ivl and VVP hashes did not change.
The full JSON rerun passes 3,652/3,652. [result.json](result.json) separates
these gates from the 0/1 released DV result. Full legacy and JSON logs are
stored as `.log.gz` to keep the PR reviewable.

The indexed associative class-property copy-out and mismatched `ref` type
acceptance found during review are separate DD-057 and DD-058; neither is
claimed fixed here. No Caliptra job, Verilator run, or GPU experiment was
performed for this work.
