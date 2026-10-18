# IEEE 1800 clause 13 probe c13c

Probe scope: §§13.4–13.4.4 (functions), with the 2023 §13.4.1 implicit-variable addition checked separately; both editions are compiled. Printed-page references: 2017 pp.325–327 and 2023 pp.341–347.

Attempt 01 uses the protected Icarus 13.0 devel toolchain built from source `9b5fad2afb4104caa816b257d5bccc40f01b8c66` on DAN-DESKTOP, 1 CPU and 1 GiB. Each compile has a 60-second timeout; each simulation has a 30-second timeout, with TERM then KILL after 2 seconds. The job checks function return forms/lifetimes/recursion, constant-function use, §13.4.4 process exceptions, the discarded-return warning and void cast, implicit-variable interpretation, and four compile-time restrictions.

Initial results: the 15-check functions probe and exactly one discarded-return warning both pass in both editions. The implicit-variable source does not compile in either edition at `F().member`; this leaves its required 2017 `F.member` check inconclusive until split. Two required errors are enforced: a duplicate function name at enclosing scope and `return;` in a nonvoid function. The compiler accepts both a duplicate local named after the function and a nonvoid function with an output argument called in a continuous assignment. The audit lead later confirmed the three gaps after targeted probes and duplicate review.

Slurm job 2296 completed in under a minute; the script returned 1 for the expected probe mismatches, not infrastructure loss. Full compiler and run output, including warnings, is kept in `attempt-01/logs/results.txt`; the exact submitted script and source hashes are alongside it.

The audit lead classified §13.4 and §13.4.1 as PARTIAL (gaps G26, G25, and G27); §13.4.2 and §13.4.4 as IMPLEMENTED. The remaining §13.4.3 restrictions were checked in c13d. Attempt 02 separates `F.member` from `F().member`: the function-scope hierarchy prints `PASS ... (4)` in both editions, while `F().member` fails to parse in both; the 2017 result is informational. The duplicate-search output is in `attempt-02/duplicates.txt`. Issues: [#634](https://github.com/dsellerbrock/iverilog-uvm/issues/634), [#635](https://github.com/dsellerbrock/iverilog-uvm/issues/635), and [#636](https://github.com/dsellerbrock/iverilog-uvm/issues/636).

Before issue filing, I read closed issue #43. It covers `enum.method()` on a function result and method calls on returned class handles; it does not report the required `F().member` property selection. Its title/body are preserved in `attempt-01/issue43-title-body.txt`.
