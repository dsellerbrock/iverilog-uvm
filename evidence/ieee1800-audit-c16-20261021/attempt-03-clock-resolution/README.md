# Clause 16.16 clock-resolution probes

Lead-selected paired probes for IEEE 1800-2017/2023 §16.16, covering clocked sequence/property instances, contextual inference, clocking-block properties, default clocks, precedence, and required diagnostics. Every source is independent, and every assertion uses a fail-only action.

Results and issue classification will be added after Slurm job completion. The open/closed issue search and snapshot are retained in `DEDUPE.md` and `dedupe-all-issues.json`.

Slurm job 3756 completed. C1/C2/C3/C5/C7 match their expected ticks; C4 rejects the standard-valid property declaration inside a clocking block; C6 uses the default posedge rather than the inferred negedge (C6a fails at 15; C6b misses the expected fail at 20). N1/N2 reject; N3 rejects with an unbound `q2` diagnostic, so that rule-specific result is inconclusive. The audit lead filed [#916](https://github.com/dsellerbrock/iverilog-uvm/issues/916) for inverted §16.16 rule (c) precedence and [#917](https://github.com/dsellerbrock/iverilog-uvm/issues/917) for rejected clocking-block property declarations. N3's binding ambiguity has a separate four-case follow-up in [`attempt-04-n3-followup`](../attempt-04-n3-followup/).
