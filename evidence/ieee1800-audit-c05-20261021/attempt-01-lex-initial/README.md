# Initial Clause 5 probe design check

This is retained as an audit trail for Slurm job 3698, not as conformance evidence for the positive lexical suite. The initial `p05_lex.sv` accidentally placed a deliberately nested block comment in the positive source, so the compiler correctly rejected it at line 12. The standalone nested-comment negative case was also rejected in both editions. `p05_lex23.sv` compiled and printed `L6 AB 2` in both editions. The corrected probe is in [`attempt-02-lexical-conventions`](../attempt-02-lexical-conventions/README.md).

The exact initial inputs, script, Slurm output, and result files are preserved here. Compiler source commit was `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`.
