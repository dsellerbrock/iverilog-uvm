# Result

- Source checkout: `m7-1800-audit-c08`, HEAD `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`; existing checkout was dirty. Probe source SHA-256: `c0e8714083f15dc6cd10fb412421bd188b68f328de2af75d90f7a7a6298eec29`.
- Host: DAN-DESKTOP Slurm, job 3515; 1 CPU, 1 GiB, 5-minute limit. Job completed; Slurm accounting is disabled. Each compiler and runtime invocation had a 30-second timeout.
- Tool: Icarus 13.0-devel `cc25756d1`; `iverilog` SHA-256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`; `vvp` SHA-256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`.
- Command form for each source: `iverilog -g{2017,2023} -s <top> -o <binary> <source>` followed by `vvp <binary>` for the positive source. Full runner: [`run.sbatch`](run.sbatch). Raw stdout/stderr and the Slurm log are in `results/` and [`slurm-3515.out`](slurm-3515.out).

## Observed

| Probe | 2017 | 2023 |
|---|---|---|
| `p07_08_assoc.sv` compile | rc 0 | rc 0 |
| `p07_08_assoc.sv` runtime | `vvp` segfault, rc 139, no test output | `vvp` segfault, rc 139, no test output |
| Different associative index type formal | rejected, rc 1 | rejected, rc 1 |
| Fixed-array formal | rejected, rc 2 | rejected, rc 2 |

The positive runtime combines class-key insertion/read (derived and null keys), unpacked-struct keys, associative assignment, by-value copy, and `ref` aliasing. The crash prevents attributing the runtime failure to one feature. Do not file a feature-specific issue until the lead's isolation step identifies it. Both negative results match the required argument incompatibility behavior in §7.9.10.

## Standards and dedupe

The probe covers IEEE 1800-2017/2023 §§7.8.3, 7.8.5, 7.9.9, and 7.9.10. Section 7.8.3 permits a class index object of the declared class or a derived class and permits a null key. Section 7.9.9 requires compatible associative index types for array assignment; §7.9.10 restricts associative-array actuals to compatible associative formals with matching index type and excludes fixed-array formals. Full dedupe search results are in [`DEDUPE.md`](DEDUPE.md).
