# IEEE 1800 §16.9.3 sampled-value probes — complete input set

This run repeats the existing procedural, default-clocking, explicit-clock,
Preponed-writer, multiclock assertion, and `$sampled` regressions, plus the
no-clock negative probe. Both `.sv` and `.v` inputs are staged. It also runs
the existing clocking-input diagnostic case. Editions are `-g2017` and
`-g2023`, assertions are enabled, and each compile and simulation has a
120-second timeout. Attempts 10 and 11 are preserved as runner/input-copy
failures; their valid `$sampled` and no-clock observations are included for
traceability, not as a substitute for this complete run.

Slurm job 3182 again did not reach the existing regressions: the runner
looked for `.sv` for every source, while the existing Icarus tests use `.v`.
As in job 3181, only `sampled_preponed.sv` and the new no-clock probe actually
ran. The complete rerun selects each source by its staged extension in
attempt 13.
