# IEEE 1800 §18.13 probe results

- Slurm job 2905 on DAN-DESKTOP; 1 CPU, 1 GiB; `squeue` no longer listed the job after completion.
- Probe source snapshot: audit worktree HEAD `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`, with the two clause-18.13 probes staged into the run input.
- Icarus 13.0 devel SHA-256: `234d4e6ee4a27f636b1b07de19e31db0ea510601945ed5aaf2885edb8e1d4f42`; VVP SHA-256: `2c18f1c5cfc8519fc72ede80878efb500d3187c681472c5935f3bb59388e0350`.
- IEEE 1800-2017 §§18.13.1–18.13.5, pp. 538–540; IEEE 1800-2023 §§18.13.1–18.13.5, pp. 560–562. Wording for the probed APIs matches in both editions.

## Positive probe

`p18_13_urandom.sv` compiled and ran in `-g2017` and `-g2023`, printing `PASS urandom clause 18.13` in both editions. It checks `$urandom` width and seeded sequence repeatability, `$urandom_range` normal/reversed/default bounds, and `srandom()`, `get_randstate()`, and `set_randstate()` replay for object and process RNGs.

## Invalid argument count

`n18_13_urandom_args.sv` calls `$urandom(1, 2)`. In both editions, `iverilog` returned 0 and produced a VVP file without a compile diagnostic. Running that file returned 1 and printed `ERROR: ... $urandom takes at most one argument. Found 1 extra argument.` The standard prototype permits zero or one argument, so the call is rejected only at runtime rather than during compilation.

The run script records this as `GATE_RESULT=FAIL` because the negative probe expected a compile-time rejection. Raw commands and outputs are in `run.sbatch`, `slurm-2905.out`, and `results/`.
