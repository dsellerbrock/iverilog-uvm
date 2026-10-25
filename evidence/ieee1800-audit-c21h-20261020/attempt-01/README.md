# IEEE 1800-2017/2023 §21.7.1.2 `$dumpvars` selection probe

IEEE 1800-2017/2023 §21.7.1.2 permits `$dumpvars` with no arguments (all
variables in the model) or with a hierarchy depth and module/variable list.
The standard's example combines a module instance with an individual
hierarchical variable.

`p21_7_1_2_dumpvars_noargs.sv` checks that `$dumpvars;` includes variables in
the top module and a child. `p21_7_1_2_dumpvars_selectors.sv` checks
`$dumpvars(0, u1, u2.b)`: both variables from `u1` and only `b` from `u2`
appear; an unselected top-level variable is absent. `verify.py` asserts the
VCD variable sets in both editions.

Both `-g2017` and `-g2023` compile and run successfully, and the VCD checks
pass. No gap or issue was identified, so no issue dedupe was needed. The
matrix remains PARTIAL because separate event and type-mapping gaps remain.

Command: `~/codex-supervisor/localrun 180 sh evidence/ieee1800-audit-c21h-20261020/attempt-01/run.sh`

Compiler source commit: `b9441bafbdb0b6b7413c09e0381845e69481391b`.
Icarus SHA-256: `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`.
VVP SHA-256: `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.
Host: macOS Darwin ARM64. Elapsed: 0.34 s. Peak RSS: 16,859,136 bytes.

Compile/run logs and VCD outputs for each edition are in `2017/` and
`2023/` beside this file.
