# IEEE 1800 constant and aggregate expression rules

## §11.2.1 constant expressions

IEEE 1800-2017 §11.2.1 lists constant numbers, strings, parameters, constant bit/part selects of parameters, constant function calls, and constant system-function calls. IEEE 1800-2023 §11.2.1 retains these and specifies non-void constant-function calls; it also adds eligible constant built-in method calls. Both editions allow the relevant constant operators and require constant system-function calls to be evaluated at elaboration. `$clog2(17)` and the pure constant function `dbl(3)` exercise the listed forms.

## §11.2.2 aggregate expressions

Both editions state: “Aggregate expressions can be copied in an assignment, through a port, or as an argument to a subroutine.” They also state: “Aggregate expressions can also be compared with equality or inequality operators.” For aggregate comparisons, “they shall be of equivalent type as defined in 6.22.2.” The copy probe checks independent value copying; the conditional expressions test aggregate results.

IEEE 1800-2017/2023 §6.22.2(d) says unpacked fixed-size array types are equivalent only when their element types are equivalent and their sizes are equal; actual range bounds may differ. Thus `int A[3]` and `int E[4]` are not equivalent and their comparison is expected to fail compilation.

## §11.4.5 equality operators

Table 11-9 defines `==` as equality with a result that can be unknown and `!=` as inequality with a result that can be unknown. §11.4.5 says: “These four operators compare operands bit for bit.” §11.2.2 explicitly admits aggregate operands and constrains them by equivalent type; both rules apply to the unpacked array and structure cases in this probe.
