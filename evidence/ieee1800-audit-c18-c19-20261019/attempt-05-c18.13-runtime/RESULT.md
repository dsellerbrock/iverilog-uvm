# IEEE 1800 §18.13 confirmation — Slurm job 2917

- Host: DAN-DESKTOP; 1 CPU, 1 GiB; `squeue` no longer listed the job after completion.
- Icarus 13.0 devel SHA-256: `234d4e6ee4a27f636b1b07de19e31db0ea510601945ed5aaf2885edb8e1d4f42`; VVP SHA-256: `2c18f1c5cfc8519fc72ede80878efb500d3187c681472c5935f3bb59388e0350`.
- Positive §18.13 probe compiled and ran in both `-g2017` and `-g2023`, printing `PASS urandom clause 18.13`.
- Invalid `$urandom(1, 2)` source compiled with exit 0 in both editions and produced VVP files. Executing each VVP returned 1 and reported the extra argument at runtime.
- This confirms the observed gap is compile-time acceptance with a deferred VVP error, not lack of any diagnostic. Raw output and generated VVP files are retained in `results/`.
