# IEEE 1800 §20.6 data-query probe

The probes ran on macOS ARM64 at commit `b9441bafbdb0b6b7413c09e0381845e69481391b`, using Icarus/vvp from the local T2 build. Each compile and simulation used `~/codex-supervisor/localrun 10`, sequentially, in `-g2017` and `-g2023`. Tool and source hashes, full logs, and the command summary are in `attempt-01-c20.6-query/` and `attempt-02-bits-isolation/`.

## Initial probe

`p20_06a_query.sv` fails compilation in both editions at line 11 with `Invalid data type for $bits().` No run occurred. The error line contains `$bits(v)` followed by `$bits(MyType)` and `$bits(mt)`.

## Isolated reducers

The four requested reducers show the issue is specific to the unpacked-struct type form: `$bits(v)` compiles and prints 32; `$bits(PT)` for an equivalent packed struct compiles and prints 9; `$bits(MyType)` for an unpacked struct type fails compilation with `Invalid data type for $bits()`; `$bits(mt)` for an unpacked struct variable compiles but prints 3 although the declared members require 9 bits. These results match in both editions.

The scratch copy `p20_06b_query.sv` removed only the `bits_struct` check and retained its same-line `$bits(v)` control. It compiles/runs in both editions but reports `FAIL tn_vec` and `RESULT pass=9 fail=1`; the `$typename(X)` comparison against `"bit [2:0]"` fails. Its informational output is `INFO tn L=[logic [7:0]] U=[int unsigned] B=[byte] SR=[shortreal] mt=[struct {logic valid;bit [8:1] data;}]`. The probe contains 10 checks after removing the struct check.

The combined `$typename` standard-example probe fails compilation in both editions at its struct declaration (`Error in struct/union member`), before it can print the literal strings. In separated literal oracles, both editions print T1 `[bit]`, T2 `[int]`, T3 `[enum{A=32'sd0,B=32'sd1,C=32'sd99}X]`, T4 `[bit [9:1]]`, and T5 `[struct {bit P;bit Q;}$[0:9]]`; the corresponding standard literals for T1, T3, T4, and T5 differ. Two struct-member collision controls also fail compilation: fields named A and B fail both when a package named A exists with no import and when the package's enum names are wildcard-imported. These results are pending the lead's standards classification and open/closed dedupe.

The audit lead classified the unpacked-struct `$bits` behavior as a §20.6.2 gap and filed [#788](https://github.com/dsellerbrock/iverilog-uvm/issues/788) after deduplication. The passing `p20_06b_query.sv` run also confirms the tested `$isunbounded` case, despite the independent `$typename` failure. GitHub confirmed #788 is open with the `1800-audit` label.

The audit lead classified the packed-range omission as a §20.6.1 gap and filed [#789](https://github.com/dsellerbrock/iverilog-uvm/issues/789). It also classified the struct-member/package-name collision as a separate gap and filed [#790](https://github.com/dsellerbrock/iverilog-uvm/issues/790) after open/closed deduplication. It classified the anonymous enum-name and struct-prefix/spacing string differences as gaps and filed [#791](https://github.com/dsellerbrock/iverilog-uvm/issues/791). The lead left T4 unclaimed because the standard example does not clearly say whether the package prefix applies to a variable. GitHub confirmed the new issues are open with the `1800-audit` label.
