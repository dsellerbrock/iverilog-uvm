# IEEE 1800 §§16.12.4–16.12.5, 16.12.8, and 16.12.16 probes

- Slurm job: `3208` on `DAN-DESKTOP`, 2026-10-19 16:02 MDT; request 1 CPU, 1 GiB, 10 minutes. Slurm accounting is disabled on this host, so peak RSS is unavailable; the run completed in under one second.
- Toolchain: Icarus main `c31cbf1b52f1a39d5775f276e2340525a444a79e`; binary hashes are recorded in `results/sha256.txt`.
- Command: `iverilog -B <toolchain>/lib/ivl -g<2017|2023> -gassertions -s test -o <result>.vvp <probe>.sv`, then `vvp -n <result>.vvp`; each process had a 120-second timeout.

Results are identical in both editions:

- **§16.12.4/.5:** The valid property operands `(a |-> b) or (c |-> d)` and `(a |-> b) and (c |-> d)` are rejected at parse time. The parse diagnostic occurs on the property expression, and follow-on no-clock messages result from the failed declaration. Current `parse.y` has sequence `and`/`or` productions but no production combining two `property_expr` operands.
- **§16.12.8:** The `implies` truth table has exactly one expected failure (`a=1,b=0`); `iff` has exactly two (`a!=b`). Both compile and run exit 0.
- **§16.12.16:** `case` compiles and runs exit 0. The `00`, `01`, and default arms are selected; only the intentionally false default case fails, giving the expected count of one.

The `.4/.5` diagnostics are a feature gap, not a desired compile failure. The test sources are in `tests/1800_audit/c16/`. Clause references: IEEE 1800-2017 §§16.12.4–16.12.5 (p. 425), 16.12.8 (p. 429), 16.12.16 (p. 438); IEEE 1800-2023 §§16.12.4–16.12.5 (p. 444), 16.12.8 (p. 449), 16.12.16 (p. 458).
