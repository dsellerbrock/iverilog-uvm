# IEEE 1800 distribution follow-up with per-case timeouts

- Standard: IEEE 1800-2017 §18.5.4 (pp. 512–513); IEEE 1800-2023 §18.5.3 (p. 531). The 2017 text states `dist` tests set membership, `:=` weights each range value, `:/` weights the range as a whole, and zero weight is a constraint. Both editions prohibit `dist` on `randc` and require at least one `rand` variable in the expression.
- Source checkout: branch `m7-1800-audit-c08`, commit `27f53df24`, dirty before this probe; inputs staged under `input/` and hashed below.
- Slurm host DAN-DESKTOP, current-main compiler 13.0-devel `cc25756d1`, 1 CPU / 1 GiB / 8 minutes. Each compile and each of seven runtime cases has its own 30-second process-group timeout.
- The first combined run (attempt-01, Slurm job 3431) timed out after D1/D2 output; the full set is split by `+CASE=n` here. It also found that `randc dist` is rejected while the non-rand negative compiles without error.
- Dedupe searches: `dedupe-open-closed.txt`. The lead classified the no-`rand` rule as distinct from closed #12 and filed #836 after reviewing the recorded searches.
- Slurm job 3436 ran 2026-10-20T14:59:43Z–15:01:17Z (94 seconds); the final `squeue` check found it complete. Peak RSS is unavailable because Slurm accounting is disabled.
- Raw runtime/compile logs, `positive.tsv`, `negative.tsv`, toolchain hashes, and stdout are in `remote-results/`; `RESULT.md` summarizes them.
