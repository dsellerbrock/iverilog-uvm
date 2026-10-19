# Attempt 11 — former unsupported stub converted to positive

- Source commit: `8a3b22a3ab527f282666ed4f5fd41ff2f7d4c58d`.
- Host: DAN-DESKTOP, Slurm job 2844, 2 CPUs / 4 GiB, exit `0:0`, elapsed 7m37s.
- Source archive SHA-256: `2f1584379201057d36940a899e90f00c252b7f59088dd43f9ecf7bda2b0fad12`.
- Compiler SHAs: `iverilog` `226d26f2f9009974a9374b30ef2f2812d8e479ced283750bfd68243dc0b3203c`; `vvp` `1486b5d4863d4c500bf07798bb3691540472a1cc378cab36d0da9d4a56f1d2db`.
- T0 issue regressions: legacy 8/8 and JSON 8/8 passed, including the converted stub in both editions.
- T0 smoke passed: VVP 56/56, VPI 133/133, and all malformed-input checks passed.
- T1 neighbors: legacy 17/17 and JSON 17/17 passed.
- Final result: **PASS** (`GATE_RESULT=PASS`). The previous attempt's access limitation was avoided by copying nested rows to local dynamic arrays before reading elements. No golden output mismatch occurred; approved positive gold remains `PASSED` with empty stderr.

Raw result files, source snapshot, run script, compiler hashes, and the two new test compile/runtime logs are in `results/` and this attempt directory.
