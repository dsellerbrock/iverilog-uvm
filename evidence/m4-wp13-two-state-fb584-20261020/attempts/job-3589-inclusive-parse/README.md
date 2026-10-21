# WP13 inclusive profile reanalysis, Slurm job 3589

Pinned M4 measurement base: `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`.
Profile source: job 3383, commit `cc25756d187314742d347267c2a513b3e640a7fb`.

This 1-CPU, 2-GiB postprocessing job re-read the three saved job 3383 perf samples with `perf script --inline`; it did not run simulations or collect new samples. The parser selects vector4 API frames, four-state operations and propagation names, plus shortened `calculate`/`receive` inline frames conservatively. Inclusive symbol shares overlap; the combined ceiling uses the union of selected samples so each sample is counted once.

| Test | Selected sample union | Ideal Amdahl ceiling |
|---|---:|---:|
| DMA AES-GCM short | 45.5348% | 1.8360× |
| SHA-256 | 47.4980% | 1.9047× |
| Caliptra ROM | 46.4574% | 1.8677× |
| Equal-weight combined | 46.4830% | 1.869× |

The Amdahl figures are upper bounds that assume all selected work disappears. The type-proven prototype can affect only a subset of unforced `.net/2u` wire reads; it cannot remove the other listed work.
