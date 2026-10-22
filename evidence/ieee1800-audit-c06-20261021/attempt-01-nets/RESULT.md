# Clause 6.6 net-type probe results

Slurm job 3764 ran 14 standalone sources under -g2017 and -g2023 with pinned Icarus 13.0 devel cc25756d1, -B, 1 CPU and 1 GiB. Every compile and simulation was limited to 30 seconds. Scheduler record: COMPLETED, ExitCode=0:0. Raw logs, source hashes, toolchain hashes and scheduler records are in raw-slurm-3764/.

The audit lead reviewed the IEEE 1800-2017 and 1800-2023 clauses and tables. The following tested subsets pass in both editions:

| Case | Result |
|---|---|
| T1 wire/tri | All 16 driver pairs match Table 6-2. |
| T2 wand/triand | All 16 driver pairs match Table 6-3. |
| T3 wor/trior | All 16 driver pairs match Table 6-4. |
| T4 tri0/tri1 | All 16 pairs match Tables 6-5/6-6; undriven strengths print Pu0/Pu1. |
| T5 supply0/supply1 | Values and strengths print 0 Su0 and 1 Su1. |
| T6 undriven wire | Prints z. |
| T7 uwire multiple drivers | Rejected at compile time with the multiple-driver error required by §6.6.2. |
| I1 interconnect port connection | Resolves through module ports and prints 1. |
| I2 interconnect continuous assignment | Rejected. |
| I3 interconnect in procedural expression | Rejected. |

I2 and I3 produce the required rejection under §6.6.8. U1-U4 are not classified by this run: the first three fail earlier because a continuous assignment pattern directly driving the unpacked-struct net is rejected; U4 emits that same pattern diagnostic as well as the expected no-resolution multiple-driver error. The follow-up controls in followup-controls/ isolate assignment-pattern handling from user-defined nettype behavior.

The paired outcomes are identical between editions for all cases. Open/closed issue dedupe snapshot: 298 open and 127 closed before any new filing.

An independent comparison against Tables 6-2 through 6-6 checked all 64 output cells across T1-T4 for each edition, plus the exact T5/T6/I1 outputs and required T7/I2/I3 diagnostics. The check report is raw-slurm-3764/results/validation-3764.txt.
