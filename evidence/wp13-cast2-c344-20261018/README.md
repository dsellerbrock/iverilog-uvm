# WP13: omit cast2 on whole two-state compound reads

Pinned source: `c344d20197a569dea8936bad95de3d185b1e78dc`.

The candidate omits the generated `%cast2` only for a whole-vector read of a
2-state signal. Part-selects and memory-word reads retain the coercion because
they can produce X/Z; 4-state signals are unchanged. The focused guard checks a
whole 2-state compound assignment, an out-of-range 2-state part-select, and
4-state preservation. No ivtest golden output is changed.

Attempt 2697 stopped before compilation because the shared partial-clone template lacked a c344 blob; attempt 2706 hit the same object-store issue. Both failures and scripts are preserved under `attempts/`.

The fresh full clone and focused guard passed in Slurm job 2707. The guard emitted two `%cast2` instructions on the reference and one on the candidate, with identical output. The 18-workload Callgrind screen completed in job 2711 on the pinned base. Every workload output matched byte-for-byte. `behav` improved only 0.612544%, below the 10% threshold; the largest non-target instruction change was +0.000054% (`fork_heavy`). WP13 is rejected and its source change should be reverted.

| Workload | Reference instructions | Candidate instructions | Change | Output |
| --- | ---: | ---: | ---: | :---: |
| `behav` | 86,069,086,820 | 85,541,875,908 | −0.612544% | identical |
| Largest other increase | - | - | +0.000054% (`fork_heavy`) | identical |

The three per-group CSV/JSON reports, compressed Callgrind profiles, job output, and local SHA-256 manifests are under [`attempts/job-2711/corpus-screen/`](attempts/job-2711/corpus-screen/). The successful build and guard artifacts are under [`attempts/job-2707/`](attempts/job-2707/).
