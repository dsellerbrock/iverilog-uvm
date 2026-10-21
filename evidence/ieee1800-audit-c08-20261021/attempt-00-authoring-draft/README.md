# Initial local probe draft

These logs record test-authoring failures from the stock Homebrew Icarus 13.0 binary, not conformance results for the staged main toolchain. The draft used class-handle comparisons that this binary does not implement, class queues that it refuses, and a parameterized-class declaration it cannot parse. The final probes avoid handle comparison and were rerun as job 3716 on DAN-DESKTOP with the pinned project toolchain; see `../attempt-01-shallow-depth/RESULT.md`.
