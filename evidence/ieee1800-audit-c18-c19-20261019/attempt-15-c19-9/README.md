# IEEE 1800 Clause 19.9 probe

This probe checks the three global coverage values (0%, 50%, 100%) from one
two-bin covergroup, then invokes `$set_coverage_db_name` and
`$load_coverage_db`. The same source is compiled and run under 1800-2017 and
1800-2023. A paired negative probe passes an integer instead of a filename and
must fail compilation.

IEEE 1800-2017 §19.9 p. 584 and IEEE 1800-2023 §19.9 p. 612 describe these
system tasks and `$get_coverage`. The clauses state that the setter chooses a
database filename for end-of-run save, the loader loads cumulative coverage
for all covergroup types, and `$get_coverage()` returns overall coverage from
0 to 100. The implementation's warnings and any absent database behavior are
recorded as evidence; a passing value probe does not imply database support.

The probe files and submitted Slurm script are frozen alongside the raw
results. The read-only toolchain is
`/home/dsell/toolchains/iverilog-a3-main-82023726-679`.

Attempt 3001 was a harness setup failure: the input archive was uploaded at
the run-directory root, while the script expected it under `input/`. No
SystemVerilog probe compiled or ran. See `RESULT.md`; these outputs are not
standards evidence.
