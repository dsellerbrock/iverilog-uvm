# IEEE 1800 §18.7 / §18.7.1 inline-constraint audit — 2026-10-17

The probe covers standard class-plus-inline constraints, caller/object scope
resolution, restricted lookup lists, `local::` variable resolution, `this`,
dotted names, expression use, infeasibility, and common inline constraint
forms in both editions. It also checks the §18.7.1 `local::this` rule and
three expected compile-time rejections.

Slurm job 2249 ran on DAN-DESKTOP (`Linux x86_64`, GCC
`15.2.0-16ubuntu1`) using the protected toolchain built from source
`9b5fad2af`. It did not rebuild Icarus. The main positive probe passed all ten
checks in both modes. The isolated `local::this` probe was rejected with a
syntax error in both modes, though §18.7.1 explicitly permits names “including
the special names this or super (i.e., local::this).” The unresolved
`this.nope` and scope-randomize lookup-list negatives were rejected with the
expected diagnostics in both modes. `std::randomize(null)` compiled in both
modes although Syntax 18-10 footnote 38 (2017) / 43 (2023) says its use “shall
be illegal.”

The lead classified §18.7 and §18.7.1 PARTIAL. Duplicate searches found no
matching issue for either gap. Issue [#620](https://github.com/dsellerbrock/iverilog-uvm/issues/620)
tracks `local::this`/`local::super`; [#621](https://github.com/dsellerbrock/iverilog-uvm/issues/621)
tracks `std::randomize(null)`. Existing #479 concerns `this` resolving to a
caller-only member and is a separate lookup error.

The first attempt's invalid module wrappers and generic syntax errors are
preserved under [`attempt-01/`](attempt-01/); those results are not used as
behavior evidence. The valid run's raw `results.txt`, per-case logs, tool
versions, hashes, and scheduler exit are in [`results/`](results/); the
lead-requested raw output is also at [`results.txt`](results.txt).
