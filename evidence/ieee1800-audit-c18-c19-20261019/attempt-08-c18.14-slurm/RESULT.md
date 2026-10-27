# Attempt 08 — thread and object stability probe passes

- Host: DAN-DESKTOP; Slurm job 2960; 1 CPU / 1 GiB; start/end recorded at 06:55:57 UTC; job completed before the next queue check.
- Toolchain: pinned main build `82023726be90ab269d6e0ef5e755ebb69e6f648c`; `iverilog` SHA-256 `17661deebeaf8180f5761c82d1eeb31f30b5605739c724cb82dc4a04975a8256`; `vvp` SHA-256 `911cd2ba4a1f1a62afeb6b9463ee18a3aab338e09cb5eb89c8b1a73b0b4138cc`.
- Source SHA-256: `3d69337c4beba47389cae082831d636a534b9dcadc7fdfcd50a4f783187faf8c`.
- Commands: `timeout 30s iverilog -g2017/-g2023 -s test`, followed by `timeout 30s vvp -n` for each edition.
- Both editions compiled and printed `PASS random stability clause 18.14`; exit codes were 0/0.
- This confirms the tested thread scheduling and object-independence checks. The probe is being expanded with an event-expression timing discriminator before assigning a broader §18.14 status.
- Raw source, command script, compile/run logs, hashes, and Slurm output are retained in this directory.
