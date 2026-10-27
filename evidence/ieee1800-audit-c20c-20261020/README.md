# §20.6 combined-query probe attempt

This attempt did not produce a new clause result. The existing
`p20_06a_query.sv` probe fails to elaborate at `$bits(MyType)` in `-g2017`
because `MyType` is an unpacked struct type. This is already tracked by
[#788](https://github.com/dsellerbrock/iverilog-uvm/issues/788), and the
matrix records the issue under §20.6.2. The runner stopped after reproducing
that known gap, before running this test in 2017 or testing the other edition.

The initial error log and localrun output are retained in `results/` and
`localrun.log`. No matrix status or issue count changed from this attempt.
