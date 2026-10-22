# Results — Slurm job 3700

- Host: DAN-DESKTOP; request: 1 CPU, 1 GiB; each compile/run had a 30-second timeout.
- Toolchain: Icarus source commit `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`; `iverilog` SHA-256 `9760f8c1ab8ad03d64761b257db74ff07603a15c4d44d2bcdba75073f006911c`; `vvp` SHA-256 `7fa3224c44e69b555fa86c1e3e048fa2709780276c6417ff8b7a7f0d63241c02`.
- Slurm accounting storage is disabled, so elapsed time, peak RSS, and scheduler exit code were unavailable. The preserved job output ends with `FINAL_STATUS=0`; `squeue -j 3700` was empty on inspection.

Both `-g2017` and `-g2023` compiled and ran `p05_lex.sv` and `p05_lex23.sv`. Both produced the same values:

```text
L1 1 1010xzz0
L2 -3 ff00000001
L3 150.0 9
L4 a<TAB>b\c"dA<newline>
L5 ok
L6 AB 2
```

`n05_nested_comment.sv` was rejected in both editions with `Possible nested comment` followed by `syntax error`, as required by §5.4. The raw compiler logs, run outputs, and full Slurm job output are in [`raw-slurm-3700/`](raw-slurm-3700/).

This is positive evidence only for the tested forms: escaped identifier use, the displayed based literal forms and signed value, a 40-bit unsized hex value preserved on assignment, exponent-form real, listed string escapes, the attribute declaration, simple block comment, and `\\x41` string escape. The tested 40-bit value is conforming in both editions: 2017 requires unsized numbers to be at least 32 bits, and 2023 explicitly requires enough bits for values wider than 32. It does not establish full Clause 5 conformance.
