# M4 structural-round closeout

Pinned M4 measurement base: fb584a251dd4cc91e56a75be662ccd5ee05c64e9.

No A/B/C runtime candidate passed the profile and semantic screens. The recorded WP reports are:
- WP13 two-state execution: evidence/m4-wp13-two-state-fb584-20261020/README.md
- WP12 process fusion: evidence/m4-wp12-process-fusion-fb584-20261020/README.md
- WP11 local levelization: evidence/m4-wp11-levelization-fb584-20261020/README.md

## Cumulative Caliptra anchor

Slurm job 3275 is the latest matched three-test, three-repeat comparison on a fixed mcycle 100–2,100 window. The current-main column in that job is commit 8c95b5cc10fc83d15b47e0364d2d7b4a2e12cac1, the M4 reference.

| Test | Campaign base f9f8e0a cycles/s (spread) | M4 reference 8c95b5c cycles/s (spread) |
| --- | ---: | ---: |
| smoke_test_dma_aes_gcm_short_1_dword | 7.821 (1.87%) | 9.913 (2.05%) |
| smoke_test_sha256 | 7.746 (2.23%) | 9.941 (3.12%) |
| cptra_ss_test_rom | 7.718 (8.40%) | 9.914 (12.89%) |
| Three-test geometric mean | 7.762 | 9.923 |

The reference is +27.84% over campaign base. The M4 target is 1.50x the reference, or 14.884 cycles/s geometric mean. M4 advanced no runtime changes, so its cumulative M4 speedup is 1.000x against the 8c95b5c anchor; this is not a fresh fb584 throughput measurement. The profile-only evidence does not establish a new cycles/s result. The target remains unmet.
