# WP3 JSON regression baseline comparison

Pinned measurement base: `c7ebca768c21c251d9c165c9aff0e363768030b1`.

The candidate-only full gate job 1242 completed its build, FPGA install, legacy
ivtest gate, and real-DPI UVM suite successfully. Its full JSON suite reported
16 failures. Job 1246 built untouched `c7ebca7`, selected those same 16 cases,
and ran the same cases on both reference and candidate installs with the
per-test harness from `run-json-isolated.py`.

Both sides produced byte-for-byte identical per-test result text for all 16
cases; `candidate-vs-reference.diff` is empty and the job completed with exit
code 0. The suite still has 16 inherited baseline failures, so this is a clean
baseline delta, not a claim that all 4662 JSON cases pass. The candidate has no
new JSON failures. The legacy gate and UVM real-DPI results remain separately
recorded in the full-gates job output.

Inputs and exact commands are recorded in `source-manifest.txt`,
`failure-names.txt`, and the parent `compare-json-baseline-r2.sbatch`. Raw
per-test results and logs are preserved beside this README.

After normalizing only the isolated `json/reference` vs `json/candidate`
output-directory name, all 16 complete failure logs are byte-identical as well.
