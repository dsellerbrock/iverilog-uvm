# Remaining Clause 32 SDF probes

Paired `-g2017`/`-g2023` tests cover SDF timing-check annotation, min:typ:max selection, `scale_factors`/`scale_type`, and a 3 ns interconnect annotation. The exact IEEE citations and corrections to the assignment's two clause/default labels are in [`STANDARD.md`](STANDARD.md).

Sources and expected outputs are in [`input/`](input/); shared probe files are [`p32_tchk.sv`](../../../../tests/1800_audit/c32/p32_tchk.sv), [`p32_mtm.sv`](../../../../tests/1800_audit/c32/p32_mtm.sv), [`p32_scale.sv`](../../../../tests/1800_audit/c32/p32_scale.sv), and [`p32_ic.sv`](../../../../tests/1800_audit/c32/p32_ic.sv). Each compile/run has a 30-second timeout. Every run uses `-gspecify`; interconnect runs also use `-ginterconnect`. The first run used full-stdout comparisons and had chatter-induced mismatches; see [`RESULT.md`](RESULT.md). The normalized rerun and final results are in [attempt 04](../attempt-04-normalized/RESULT.md).
