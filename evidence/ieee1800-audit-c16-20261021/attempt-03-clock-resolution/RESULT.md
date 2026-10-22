# §16.16 clock-resolution results

Slurm job 3756 on DAN-DESKTOP, Icarus 13.0 devel `cc25756d1`, pinned `-B`, `-gassertions`, both `-g2017` and `-g2023`. Requested 1 CPU, 1 GiB, 5 minutes; each compile/run had a 30-second timeout. Scheduler reports `COMPLETED`, `ExitCode=0:0`, runtime 1 second. Per-case status and raw logs are under `raw-slurm-3756/`; accounting storage is disabled, so peak RSS is unavailable.

| Case | Per-edition result | Interpretation |
|---|---|---|
| C1 sequence instance with explicit clock | compile/run 0/0; `C1 FAIL 15` | Matches. |
| C2 property with explicit clock | 0/0; `C2 FAIL 15` | Matches. |
| C3 inferred clock from `always @(negedge clk)` | 0/0; `C3 FAIL 20` | Matches the inferred negedge without a default clock. |
| C4 property declared inside clocking block | compile rc 5 with syntax/invalid-module-item errors at the standard-valid declaration | Does not implement the permitted clocking-block property declaration. |
| C5 default negedge clock | 0/0; `C5 FAIL 20` | Matches. |
| C6 inferred negedge should override default posedge | 0/0; `C6a FAIL 15`, no `C6b` failure at 20 | Uses default posedge for the procedural assertion. This contradicts §16.16 rule (c); C3 and C7 act as controls. |
| C7 explicit negedge should override default posedge | 0/0; only `C7b FAIL 20` | Matches rule (d). |
| N1 explicit event inside a clocking-block sequence declaration | compile rc 6 with syntax errors | Rejected as required by rule (b1). |
| N2 assertion with no explicit, default, or inferred clock | compile rc 1 with “concurrent assertion has no clocking event…” | Correctly rejected. |
| N3 multiclocked property with inferred procedural event | compile rc 1, but diagnostic is `Unable to bind ... q2` | Rejected, though this does not establish that the required multiclock diagnostic is issued. Treat the specific clock-precedence rule as inconclusive without lead direction. |

In C6, `a` is low only at posedge 15 and `b` is low only at negedge 20. C3 demonstrates inferred negedge sampling alone; C5 demonstrates default negedge sampling; C7 demonstrates an explicit negedge superseding a posedge default. C6 instead fires on the default posedge and misses the negedge `b=0` case.

Issue search details and the 419-issue snapshot (292 open, 127 closed) are in `DEDUPE.md`. The open/closed search found no direct §16.16 issue. It distinguished #679 (procedural sampled-value function with default clocking), #710 (no clock inferred for sampled-value functions), and #700 (endclocking identifier label).

The audit lead verified the controlling text in both standards and filed two new issues. #916 cites IEEE 1800-2017 §16.16(c) p. 476 and IEEE 1800-2023 §16.16(c) p. 496: “A contextually inferred clocking event from a procedural block supersedes a default clocking event.” C6 reproduces the inverse precedence in both editions. #917 cites §16.16(b), §14.3 and A.6.11: the standard permits property and sequence declarations in a clocking block and says their clocking event acts as an explicit leading event, but C4's standard-valid property declaration fails to parse in both editions. The lead directed a four-case N3 follow-up to resolve whether its unbound-property diagnostic is a binding gap or masks the multiclock rule(c) check; results are recorded under `../attempt-04-n3-followup/`.
