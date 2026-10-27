# §20.15 / 2023 §20.14 seeded distribution functions

Slurm job 3550 ran the Annex N oracle and `p20_15_dist.sv` against the pinned main compiler `cc25756d187314742d347267c2a513b3e640a7fb` on DAN-DESKTOP (1 CPU, 1 GiB, 10-minute limit). The job completed with exit code 0. `sbatch --wait` returned in about two seconds including SSH overhead; Slurm accounting is disabled, so exact job runtime and peak RSS are unavailable.

The C oracle was compiled with `gcc -std=gnu89 -O0 -fwrapv oracle/dist.c -lm`, then run once. Each Icarus edition was compiled with `-B /home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/lib/ivl -g2017` or `-g2023` and run under a 30-second timeout. Compile, runtime, and output-diff statuses were all 0 for both editions. Raw commands and output are preserved under [remote-3550](remote-3550/).

The oracle source hash is `ee0b28bf6aec41b1abb0a42eed735d110a167e23a1fadb35c974140fe6cfaf14`; the probe hash is `0b42a0ceff8abad4ff67a9ad26e81183f5566ccf88b3b92be622aa60ceb314fa`. Tool hashes are recorded in `remote-3550/sha256.txt`.

The output from the oracle and both editions is byte-identical:

```text
$random -2147414528 -1671855048 1129920902 -1374483364 1730349006 seed -417135238
$dist_uniform 0 11 77 18 91 seed -417135238
$dist_normal 6 -24 2 8 -4 seed 584849259
$dist_exponential 110 22 3 17 1 seed -417135238
$dist_poisson 0 5 5 4 5 seed 799809129
$dist_chi_square 1 2 1 5 1 seed -1217539842
$dist_t 0 -7 1 0 2 seed 1692139853
$dist_erlang 66 10 1 8 9 seed 797919023
```

The oracle preserves the Annex N C source and maps its assumed 32-bit `long` and wraparound to the 32-bit host model described in [STANDARD.md](../STANDARD.md). The Annex N.2 algorithms in IEEE 1800-2017 and 1800-2023 were compared; their algorithm statements match.
