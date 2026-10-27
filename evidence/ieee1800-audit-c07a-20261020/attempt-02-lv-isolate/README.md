# §7.10 l-value isolation and runtime control (Slurm job)

This job runs each `Q[$+1]`, `Q[$]`, `Q[$-1]`, `Q[Q.size()]`, and bounded-queue `$+1` case as its own source under `-g2017` and `-g2023`. It also reruns the full §7.10 probe with only `q[$+1]` → `q[q.size()]` and `b[$+1]` → `b[b.size()]`. The exact two-line source diff is `queue-size-only.diff`; full test data output is compared with `input/expected/full.txt`.

All compile diagnostics, stdout, stderr, exit codes, timing, and warning lines are captured separately. Each compiler and simulation invocation has a 30-second timeout. The required invalid-write and bounded-queue warnings are preserved verbatim in `results/warnings.txt` and quoted in the result report.

The six required issue searches were previously run against both states and are copied to `dedupe-open-closed.txt`; all returned empty. Resources: 1 CPU, 1 GiB, 20 minutes.

## Archive integrity

- `input.tar.gz`: 2207 bytes; SHA-256 `117fc62cedc6defd0023941729d30bfb14670a3f664254002332f42ac2ed8eba`.
- `results-3510.tar.gz`: 7512 bytes; SHA-256 `000e4b4daf6b456f0b2c197b6e732185352aa9d3764dce4ed2dafaef146446f0`.
