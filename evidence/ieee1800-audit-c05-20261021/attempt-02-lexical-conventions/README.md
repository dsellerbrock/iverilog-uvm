# IEEE 1800 Clause 5 lexical-convention probes

This corrected attempt keeps the positive lexical checks free of intentionally invalid syntax and tests non-nesting comments separately as a negative compile. It covers escaped identifiers, based literals and signed values, exponent-form real values, string escapes, attributes, and block comments under both `-g2017` and `-g2023`. The standards basis and exact edition notes are in [`STANDARD.md`](STANDARD.md).

Inputs are stored in [`input/`](input/) and link to the shared source probes at [`p05_lex.sv`](../../../tests/1800_audit/c05/p05_lex.sv), [`p05_lex23.sv`](../../../tests/1800_audit/c05/p05_lex23.sv), and [`n05_nested_comment.sv`](../../../tests/1800_audit/c05/n05_nested_comment.sv). The run used protected Icarus source commit `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`, 1 CPU, 1 GiB, and 30-second per-command timeouts; see [`RESULT.md`](RESULT.md) for the results and [`raw-slurm-3700/`](raw-slurm-3700/) for captured outputs.
