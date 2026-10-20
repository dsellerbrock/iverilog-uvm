# M3 current-main profile refresh, `8c95b5c`

Pinned profile source: `8c95b5cc10fc83d15b47e0364d2d7b4a2e12cac1`. This is the current-main remeasurement after `origin/main` advanced beyond the earlier `cae0356` profile and changed runtime files. The existing `perf record` protocol is repeated on this immutable source: three Caliptra top-level tests over mcycle 100–2,100 and the 18-workload corpus, with one pinned CPU and input/output hash checks.

Slurm job 3274 completed on DAN-DESKTOP, Intel Core Ultra 9 285K, CPU 8, with `perf` 7.0.14. All three Caliptra runs covered exactly 2,000 mcycles and all 18 corpus reports have zero lost samples. The compressed archive is `attempts/job-3274-results/m3-current-main-profile.tgz`, SHA-256 `8e2b16ee6530bf11a65c233f501cafe3e6924a8ff0463ae62187b70df763e11c`; its 126 files also verified against the job's own manifest.

| Caliptra test | Elapsed | Largest samples |
|---|---:|---|
| DMA AES-GCM | 209.332 s | `of_LOAD_VEC4` 8.74%; `vthread_run` 3.47%; `copy_from_big_` 3.37%; `_int_malloc` 3.05%; `vthread_schedule_list` 3.02%; `__dynamic_cast` 2.78% |
| SHA-256 | 188.835 s | `of_LOAD_VEC4` 9.26%; `copy_from_big_` 3.34%; `vthread_run` 3.31%; `_int_malloc` 2.77%; `malloc` 2.75%; `cfree` 2.62% |
| ROM | 204.506 s | `of_LOAD_VEC4` 11.64%; `of_PROP_INDEX_CHECK` 4.53%; `vthread_run` 3.30%; `vvp_vector4_t::setarray` 3.26%; `copy_from_big_` 3.04%; `vthread_schedule_list` 2.78% |

The 18-workload leaders remain workload-specific: `mul` in `wide_vectors` (31.25%), `send_vec4` in `rtl_alu` (16.28%), decimal conversion in `io_text` (15.87%), callbacks in `vpi_callbacks` (14.99%), and lexer/parser startup in `uvm_config_factory` (10.24%/9.22%). `send_vec4` is only 1.73–1.84% in Caliptra. No remaining Caliptra hotspot other than the already merged WP4 `of_LOAD_VEC4` reaches 10% self samples; the largest remaining one is `of_PROP_INDEX_CHECK` at 4.53%. The four largest remaining ROM symbols sum to 14.13%, an optimistic 1.164x sampled-CPU-time Amdahl ceiling, not an end-to-end speedup guarantee.
