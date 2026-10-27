# §23.3 instance and port-connection results

Host: macOS localrun. Toolchain: compiler `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`; VVP `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.

The positive probe compiles/runs in both editions. Output is `CNT 5` three times, `D 0007 0007 0007 0007 0007`, and `ROOT 3`. The isolated default probe shows omitted and explicitly empty input connections both use the declared default (`D1=5`, `D2=5`), while an explicit value overrides it (`D3=0`). The explicit-empty result is a violation of §23.3.2.2 and was filed as [#810](https://github.com/dsellerbrock/iverilog-uvm/issues/810).

| Negative | 2017 | 2023 | Outcome |
|---|---:|---:|---|
| positional plus named | reject | reject | Syntax error |
| duplicate named connection | reject | reject | Already bound |
| duplicate wildcard `.*` | accept | accept | Exit 0; grouped with missing instance parentheses in [#811](https://github.com/dsellerbrock/iverilog-uvm/issues/811) |
| undeclared `.name` shorthand | reject | reject | Unresolved input port expression |
| zero-port instance without parentheses | accept | accept | Exit 0; grouped with repeated wildcard in [#811](https://github.com/dsellerbrock/iverilog-uvm/issues/811) |
| inout connected to variable | reject | reject | Inout net-expression diagnostic |
| unconnected `ref` port | accept | accept | Exit 0 with unsupported-reference warning; filed as [#812](https://github.com/dsellerbrock/iverilog-uvm/issues/812) |
| procedural assignment to output-connected variable | reject | reject | Elaboration error |
| unconnected interface port | reject | reject | Elaboration error |
| unpacked dimension mismatch | reject | reject | Elaboration error |

Seven other negatives were correctly rejected in both editions. All run logs and commands are preserved per edition/case.
