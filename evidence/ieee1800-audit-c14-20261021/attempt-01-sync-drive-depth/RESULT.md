# Results — Slurm job 3743

## Reproduction conditions

- Standards: IEEE 1800-2017 §§14.12–14.16.1 (PDF pp.344–351) and 1800-2023 matching clauses (PDF pp.362–370; printed pp.361–369).
- Host: DAN-DESKTOP, job 3743, source commit 0f8d0292d02126fef19f2f51b6fd58b0c086470f, 1 CPU, 1 GiB requested, completed exit 0 in 1 second.
- Toolchain: Icarus 13.0 devel (cc25756d1); exact binary hashes are in results/toolchain.txt and results/SHA256SUMS.
- Each test used a 30-second timeout, pinned -B tool path, and both -g2017 and -g2023. Raw compile/run output and exit codes are retained under logs/ and results/status.tsv.

## Paired outcomes

| Probe | Observed in both editions |
|---|---|
| K1 zero-skew virtual-interface drive | Compiles/runs; data becomes A5 at t=5 and is A5 at t=6 |
| K2 numeric output skew | Compiles/runs; data becomes A5 at t=7 |
| K3 cycle-delayed synchronous drive | Compile/code generation fails: “this nonblocking property assignment form is not yet supported without changing its NBA semantics” |
| K4 selected clockvar drive | Compiles/runs; A0 becomes AF at t=5, preserving upper bits |
| K5 input sampling | Compiles/runs; sampled values at t=5/15/25 are 0/1/2 |
| K6 clockvar event control | Compiles/runs; event is observed at t=15 with sampled value 1 |
| K7 off-clock drive | Compiles/runs; a t=8 drive takes effect at t=15 |
| K8 scalar net clockvar output | Compiles/runs; net begins at Z and becomes 1 after the t=5 drive |
| K9 default cycle delay | Compiles/runs; ##3 resumes at t=25 |
| K10 inout drive/sample distinction | Compiles/runs; at t=7 sampled cb.x and signal are both 00; signal is 77 at t=16 |
| G1 global clock event | Compiles/runs; three clock events produce count 3 |
| G2 nested global-clock lookup | Compiles/runs; shared submodule counts are 3 and 2 for the two parent clocks |
| N1 duplicate default clocking | Correctly rejected with a multiple-default-clocking diagnostic |
| N2 instantiated module without its own default | Unexpectedly compiles cleanly with ##1 inside the child module |
| N3 blocking clockvar write | Unexpectedly compiles cleanly with no diagnostic |
| N4 regular intra-assignment delay in clockvar drive | Unexpectedly compiles cleanly with no diagnostic |
| N5 continuous clockvar write | Rejected during elaboration (“Net top.bus.cb.data is not defined in this context”) |
| N6 duplicate global clocking | Correctly rejected with a multiple-global-clocking diagnostic |

The expected pass/fail classifications come from the standard requirements summarized in README.md and the lead's Clause 14 review. No issue has yet been filed by the runner.

## K3 direct-hierarchy follow-up — Slurm job 3746

The same cycle-delayed drive through top.bus.cb compiles and runs in both editions. It prints AFTER 5000, changes data to 3C at 25000, and prints FINAL 31000 3C. Together with K3's virtual-interface form failing code generation in both editions, this isolates the gap to code generation for a cycle-delayed clocking drive through a virtual interface, not general direct-hierarchy cycle-delayed drive support. Job 3746 completed exit 0 in under one second with 1 CPU and 1 GiB requested; source, hashes, raw logs and scheduler state are under followup-k3-direct/.

Both positive drive cases report simulator time in 1 ps units (for example, 5000 means 5 ns).
