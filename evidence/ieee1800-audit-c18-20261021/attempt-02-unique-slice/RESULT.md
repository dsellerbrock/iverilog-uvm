# Paired-edition results

## Provenance

- Host: DAN-DESKTOP, Slurm job 3720; 1 CPU, 128 MiB, 10-minute limit; each source/edition had a 60-second timeout.
- Toolchain: Icarus 13.0-devel at `/home/dsell/toolchains/iverilog-uvm-main-cc25756d187314742d347267c2a513b3e640a7fb`, commit `cc25756d`; `iverilog` SHA-256 `87bb417df23d260bcfde3fb372b4a80eaad69e4fd2eea1ffb8b0eff10f7af08e`, `vvp` SHA-256 `dfc193c466a70a0917a16ab4198a111de616657d6004de79456db2a4b603b437`.
- Inputs were staged from branch `m7-1800-audit-c08`, HEAD `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`; source hashes are in `INPUT-SHA256SUMS.txt`.
- All ten runs completed without timeout. Runtime was 0.06–0.10 seconds per case; peak RSS was 39,392–40,816 KiB. Full per-case logs and `slurm-3720.out` are preserved here.

## Results

| Case | `-g2017` | `-g2023` | Observation |
|---|---:|---:|---|
| U1 `unique {a[0:1]}` | 0/50 | 0/50 | Compile warning says the constraint is not representable; each `randomize()` returns 0 with the explicit “constraint state read” refusal. |
| U2 `unique {a[1:0]}` | 0/50 | 0/50 | Same solver refusal for the reverse-range slice. |
| U3 `unique {a[i:i+1]}`, `i=1` | 0/50 | 0/50 | Same solver refusal for the non-rand variable-bound slice. |
| U4 `unique {a[0:1], b}` | 0/50 | 0/50 | Same solver refusal for the mixed slice/scalar group. |
| U5 `unique {a}` whole-array control | 50/50 | 50/50 | Every sampled array has pairwise-distinct elements. |

U1–U4 each produce 50 explicit runtime errors per edition; U5 has no warning or runtime error. The results match the existing #839 issue: solver refusal is specific to array-slice members, not whole arrays. No new issue is needed.
