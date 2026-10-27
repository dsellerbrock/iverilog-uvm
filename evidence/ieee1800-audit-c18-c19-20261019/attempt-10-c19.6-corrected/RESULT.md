# §19.6 corrected positive probe — Slurm attempt 10

- Job: 2987 on DAN-DESKTOP, 1 CPU / 1 GiB, 1 second, exit 1.
- Pinned toolchain: iverilog SHA-256 `17661deebeaf8180f5761c82d1eeb31f30b5605739c724cb82dc4a04975a8256`; VVP SHA-256 `911cd2ba4a1f1a62afeb6b9463ee18a3aab338e09cb5eb89c8b1a73b0b4138cc`.
- Positive probe compiled and passed all explicit/implicit cross, iff, user-bin, and auto-bin checks in both -g2017 and -g2023.
- Direct expression cross was rejected in both editions.
- The initial out-of-group probe compiled in both editions, but the lead determined it only created an implicit variable coverpoint: the unqualified `ca` did not refer to the first covergroup. No gap is inferred from that invalid probe.
- Corrected hierarchical and scope-qualified cross-group probes are being tested in attempt 11.
- Raw output and source archive are retained under `results/`.
