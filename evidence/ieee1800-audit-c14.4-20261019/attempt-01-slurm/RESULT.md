# Clause 14.4 audit — Slurm job 3159

- Standard scope: IEEE 1800-2017 §14.4, pp. 338–340; IEEE 1800-2023 §14.4, pp. 356–358.
- Clean source: `origin/main` at `c31cbf1b52f1a39d5775f276e2340525a444a79e`.
- Host: DAN-DESKTOP; 2 CPUs / 3 GiB requested; build wall time 3:03.60; build peak RSS 1,662,608 KiB.
- Icarus SHA-256: `c2c583b937ab2a92c05de1a1ccc3eb4b2598e7dfd4dca14b51e56a07564f6d33`; VVP SHA-256: `66f44d66f5b1fe97187c92c47cd51f99ef1e69c998fcfd5fac68ebd906b172df`.
- Slurm job 3159 completed with `ExitCode=0:0` in 00:03:09 after all eight compile/run checks; raw results and Slurm logs are saved here. Remote/local file checksums match.

## Results

- `p14_04_zero_step_skew`: PASS with `-g2017` and `-g2023` (`#1step` input sampling and output `#0` drive).
- `p14_04_numeric_skew`: PASS with both editions (input `#2ns` samples before the event; output `#2ns` drives at the requested delay).
- `p14_04_edge_skew`: PASS with both editions (output negedge skew).
- `n14_04_nonconstant_skew`: rejected with both editions. Both diagnostics identify `dyn_skew` as a variable not allowed in a constant expression.

All seven tested §14.4 behaviors matched their expected results in both editions; no gap was found in this subset. Probe sources are in `../../../tests/1800_audit/c14/`.

Cleanup removed the run's source, install and input trees after recording the results, freeing 1,629,962,254 bytes (1.63 GB; 1.52 GiB). Results and logs remain on DAN-DESKTOP and locally.
