# Caliptra first L0 case on the VIF-integrated Icarus build

The [runner command](compile.command.json), [compile log](compile.log),
[summary](summary.json), and [case result](smoke_test_veer/result.json) record
the released `smoke_test_veer` case with explicit `-gcommercial-unsafe`.
The original non-`VERILATOR` testbench, bundled BFM, assertions, firmware
loading, and `TESTCASE PASSED/FAILED` monitor remained active. The filelist
copy excludes only the unused invalid proprietary AXI4PC placeholder.
Pinned Caliptra and Adams Bridge sources stayed clean.

Firmware and simulation exited zero, with one pass marker, no fail marker,
633 retired instructions, 4,348 cycles, and 634 instruction-trace commits.
The qualifying result is still **0/1 nonstandard compatibility**, with 51
selected cases unrun: 17,863 assertion/error diagnostics violate the
unchanged zero-error gate. Sixteen plain errors and three reset-SVA errors
occur at time zero or the first 5 ns edge. The remaining 17,844 messages
come from side-effecting KV/MLDSA checker functions; they do not establish
an assertion pass. The earlier PIC-only compiler produced the same case
verdict, but this replay uses the VIF-integrated compiler and a newly
generated VVP image. Large simulator and trace logs remain local and can be
regenerated with the runner.
