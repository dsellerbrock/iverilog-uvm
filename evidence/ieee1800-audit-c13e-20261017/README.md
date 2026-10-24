# Clause 13.7–13.8 probe (c13e)

Run 2530 on DAN-DESKTOP used the pinned clean-main toolchain from commit
`9b5fad2afb4104caa816b257d5bccc40f01b8c66` (Icarus 13.0 devel). The exact
compiler/runtime hashes, input hashes, commands, raw output, and per-case logs
are in [attempt 03](attempt-03/results.txt).

On both `-g2017` and `-g2023`, module-scope forward references to functions and
tasks and an enclosing-scope function call from a named block passed. The
procedural parameterized static-method examples also passed, including the
standard encoder/decoder expected values; creating an object of a virtual
class was rejected with the expected diagnostic.

The module-function control in a continuous assignment passed (`y=6`). A plain
class static method in a continuous assignment and the parameterized static
method example both failed elaboration with an internal null-expression error.
This probe supports the §13.8 gap recorded in [issue #642](https://github.com/dsellerbrock/iverilog-uvm/issues/642); it is not specific to parameterization. The
harness `FINAL_STATUS=1` reflects those expected gap findings.

The matrix marks only the probed §13.7 subset IMPLEMENTED and §13.8 PARTIAL.
The negative virtual-class probe is not used to claim §8.21 conformance.
