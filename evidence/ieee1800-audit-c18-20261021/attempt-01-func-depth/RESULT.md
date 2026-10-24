# Paired-edition results

## Provenance

- Host: DAN-DESKTOP, Slurm job 3719; 1 CPU, 1 GiB, 10-minute limit; each case/edition had a 60-second timeout.
- Toolchain: Icarus 13.0-devel, `/home/dsell/toolchains/iverilog-uvm-main-cc25756d187314742d347267c2a513b3e640a7fb`; source commit `cc25756d`; `iverilog` SHA-256 `87bb417df23d260bcfde3fb372b4a80eaad69e4fd2eea1ffb8b0eff10f7af08e`, `vvp` SHA-256 `dfc193c466a70a0917a16ab4198a111de616657d6004de79456db2a4b603b437`.
- Probes were staged from branch `m7-1800-audit-c08`, HEAD `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`; source hashes are in `INPUT-SHA256SUMS.txt`.
- All ten runs completed without timeout. Runtime was 0.10–0.48 seconds per case; peak RSS was 39,428–40,524 KiB. Individual logs and the Slurm output are preserved in this directory.

## Results

| Case | Expected per lead | `-g2017` | `-g2023` |
|---|---|---|---|
| G1 non-rand state argument | 50/50, `length=2` | 50/50, `length=2` | 50/50, `length=2` |
| G2 #844 shape | 1–27 of 200 | 0/200 | 0/200 |
| G3 inline `length < 3` | 1–27 of 200 | 0/200 | 0/200 |
| G4 satisfiable bound `length <= 10` | 200/200 | 200/200 | 200/200 |
| G5 implication | 200/200 | 8/200 | 8/200 |

G2 and G3 fail their expected success range in both editions. G5 also fails the lead's 200/200 expectation, although each of its 8 successful calls satisfied both assertions (`bad=0`). The G5 result needs the lead's interpretation before expanding #844's scope. No timeouts or infrastructure failures occurred.
