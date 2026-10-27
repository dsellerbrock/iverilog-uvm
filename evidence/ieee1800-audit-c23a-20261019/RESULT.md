# §23.2 port probe results

Host: macOS localrun. Toolchain: compiler `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`; VVP `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.

The corrected full positive command (`-s top` before `-o`) fails both editions at `mh22` in `p23_02a_ports.sv:19`, with `Superfluous comma in port declaration list`. The minimal `p23_02b_mh22_probe.sv` reproduces the same error in both editions. The lead confirmed this is legal syntax from the standard's own §23.2.2.3 example, and filed [#809](https://github.com/dsellerbrock/iverilog-uvm/issues/809). The minimal `p23_02c_mh3_probe.sv` fails because a port without a direction defaults to inout; the lead confirmed the literal connection is illegal, so this was a probe error and not a simulator gap.

The broad positive test with only `mh22` and `mh3` removed compiles and runs in both editions. It prints the expected `MH19 32`, `D32 0fff00ff`, `EXT 00ff ffff ffff`, `F ff`, and `CF 1`.

| Negative case | 2017 | 2023 | Observed |
|---|---:|---:|---|
| non-ANSI redeclaration | reject | reject | Duplicate declaration error |
| ANSI body redeclaration | reject | reject | Duplicate declaration error |
| `var` with no direction | reject | reject | Implicit inout/reg diagnostic |
| variable output port default | accept | accept | Exit 0; legal for a variable output port |
| port range mismatch | reject | reject | Port range mismatch error |
| mixed ANSI/non-ANSI styles | reject | reject | Duplicate declaration error |

The `output int` default is legal; §23.2.2 p.702 prohibits initialization of output ports that are not variable outputs. The lead classified the other five negatives as conforming rejections. Per-run command and localrun resource logs are saved beside each case. The initial invocation with `-s` after the source was a command-order mistake; it is not evidence. Corrected invocations are under `ports-positive-corrected-*`.
