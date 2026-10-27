# IEEE 1800 distribution additions and edition deltas

- Scope: IEEE 1800-2017 §18.5.4 (pp. 512–513) vs. IEEE 1800-2023 §18.5.3 (pp. 531–533). The 2023 edition adds additive weights for values appearing in multiple items, range-weight calculation over the full range including values excluded by other constraints, and `default :/` syntax.
- Lead-selected probes: E1 additive weight, E2 repeated value with zero plus nonzero weight, E3 edition-specific excluded range weight, E4 default range, E6 soft distribution under a hard inline constraint; negative syntax cases for `default :=` and duplicate defaults.
- Source checkout: branch `m7-1800-audit-c08`, commit `27f53df24`, dirty before this probe. Each run is staged under `input/` and hashed below.
- Slurm plan: DAN-DESKTOP, Icarus 13.0-devel `cc25756d1`, 1 CPU / 1 GiB / 8 minutes. Each compiler and runtime process has a 30-second process-group timeout. The four E1/E2/E3/E6 cases are split by `+CASE=n` to keep each process bounded.
- Open/closed searches: `dedupe-open-closed.txt`.
- Slurm job 3437 ran 2026-10-20T15:06:44Z–15:08:12Z (88 seconds), 1 CPU / 1 GiB. The current-main compiler was Icarus 13.0-devel `cc25756d1`; compiler/VVP hashes and raw logs are under `remote-results/`.
- E1/E2/E3/E6 complete in both editions. E3 produces about 3:1 in `-g2017` as well as `-g2023`, contrary to 2017's expected 1:1; the lead filed #837. E4 compiles in 2023 but its 8000-sample runtime hit 30 seconds, so it needs a bounded follow-up. The 2017 default form is correctly rejected.
