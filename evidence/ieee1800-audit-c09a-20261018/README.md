# Clause 9.3 probe (c09a)

The accepted results are in [attempt 03](attempt-03/results.txt), Slurm job
2534, on pinned clean-main commit `9b5fad2afb4104caa816b257d5bccc40f01b8c66`
(Icarus 13.0 devel). The probe passed in `-g2017` and `-g2023`: 17 checks,
`DONE fails=0`, the 2023 block-item initialization result was 4, `ref static`
was accepted only in 2023, and the five focused negatives were rejected with
the expected diagnostics. The §9.3.1–§9.3.4 rows record only these tested
subsets; §9.5 remains unassessed.

Attempts 01 and 02 are retained as harness failures and are not used as
evidence: attempt 01 stopped in the metadata pipeline because `head` closed
the version-output pipe under `pipefail`; attempt 02 looked for the legal
`ref static` source in the `neg/` directory, so that one expected-rejection
result was a missing-file error. Attempt 03 fixed both and is the sole valid
result.
