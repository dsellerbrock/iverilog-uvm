# M4 structural-round closeout

Pinned M4 measurement base: fb584a251dd4cc91e56a75be662ccd5ee05c64e9.

WP11 and WP12 remain closed with no runtime candidate. WP13's inclusive re-screen and pinned-base A/B are complete; the narrowly type-proven wire-read prototype was rejected after a −0.87% geometric-mean result. The recorded WP reports are:
- WP13 two-state execution: evidence/m4-wp13-two-state-fb584-20261020/README.md
- WP12 process fusion: evidence/m4-wp12-process-fusion-fb584-20261020/README.md
- WP11 local levelization: evidence/m4-wp11-levelization-fb584-20261020/README.md

## What the profiles bound

For WP13, the inclusive union of vector4-plane API, arithmetic, comparison, construction, resize, propagation, and net-functor sample stacks is 45.53–47.50%, a deduplicated ideal Amdahl ceiling of 1.836–1.905x (1.869x equal-weight combined). Generic interpreter load/store dispatch is excluded. These are broad upper bounds, not attainable gains: the profile does not label samples by signal type, and the tested prototype can change only the unforced `.net/2u` `vvp_wire_vec4::vec4_value` path. Its three-test A/B regressed all cases (geometric mean −0.87%) and was rejected. For WP12, the whole `vthread_run` symbol is 3.25–3.65% in Caliptra, while the corpus `multi_clock` row at 15.65% has no repeated trigger sets. WP11 has no eligible fused group, and the earlier MUXZ prototype changed an observable delta trace. These are limits of the screened paths, not a global VVP performance ceiling.

## Cumulative Caliptra anchor

Slurm job 3275 is the latest matched three-test, three-repeat comparison on a fixed mcycle 100–2,100 window. The current-main column in that job is commit 8c95b5cc10fc83d15b47e0364d2d7b4a2e12cac1, the M4 reference.

| Test | Campaign base f9f8e0a cycles/s (spread) | M4 reference 8c95b5c cycles/s (spread) | Pinned base fb584a251 cycles/s (spread) | Rejected candidate cycles/s (spread) |
| --- | ---: | ---: | ---: | ---: |
| smoke_test_dma_aes_gcm_short_1_dword | 7.821 (1.87%) | 9.913 (2.05%) | 10.537 (1.33%) | 10.408 (1.69%) |
| smoke_test_sha256 | 7.746 (2.23%) | 9.941 (3.12%) | 10.566 (1.62%) | 10.511 (2.15%) |
| cptra_ss_test_rom | 7.718 (8.40%) | 9.914 (12.89%) | 10.537 (0.62%) | 10.446 (1.10%) |
| Three-test geometric mean | 7.762 | 9.923 | 10.547 | 10.455 |

The reference is +27.84% over campaign base. The M4 target is 1.50x the reference, or 14.884 cycles/s geometric mean. Job 3570 measured the pinned base at +35.88% over campaign base and the rejected candidate at +34.69%; both remain below target. The candidate's matched change was −0.87% with all normalized logs and firmware inputs identical. The documented limits apply to these profiled paths rather than proving a global VVP ceiling.
