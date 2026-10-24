# Attempt 07 — probe used unsupported chained process call

- Host: DAN-DESKTOP; Slurm job 2959; 1 CPU / 1 GiB; the job completed in under a second.
- Toolchain: pinned Icarus main build `82023726be90ab269d6e0ef5e755ebb69e6f648c`; `iverilog` SHA-256 `17661deebeaf8180f5761c82d1eeb31f30b5605739c724cb82dc4a04975a8256`, `vvp` SHA-256 `911cd2ba4a1f1a62afeb6b9463ee18a3aab338e09cb5eb89c8b1a73b0b4138cc`.
- The test did not compile in either edition. The compiler rejected `process::self().srandom(...)` with `srandom is not a method of class process`; no runtime stability behavior was exercised.
- The audit probe now uses the project's already-supported `process` handle idiom (`thread = process::self(); thread.srandom(...)`) and is rerun as attempt 08. The original source snapshot, compiler diagnostics, status, and scheduler log are retained here.
