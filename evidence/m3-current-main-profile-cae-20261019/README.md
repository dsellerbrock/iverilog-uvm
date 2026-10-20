# M3 current-main profile refresh, `cae0356`

Pinned profile base: `cae035642e056644274a01e98d4422ce286685b4` (the #658 merge commit and `origin/main` at profile start).

This refresh repeats the established `perf record` protocol on the exact current main: three Caliptra top-level firmware tests over mcycle 100–2,100 and all 18 sim-hotspots workloads, with one pinned CPU and output/input hash checks. The source commit, profile script, and raw job artifacts are preserved here. The Slurm job built this immutable commit in its isolated run directory.

## Job 3009 results

Slurm job 3009 (rerun 2) completed successfully on DAN-DESKTOP, Intel Core Ultra 9 285K, CPU 13, with `perf` 7.0.14. All three Caliptra tests covered exactly 2,000 mcycles; each profile and all 18 corpus profiles report zero lost samples. Corpus runs lasted 3.995–14.076 seconds and returned success. The archive SHA-256 is `4a79a414feee56e7fc2c0338817f55585986b0baa551cdc885d9fa86d6f58ca0`; all 126 entries in the saved artifact manifest verified after extraction.

| Caliptra test | Window | Elapsed | Largest remaining self samples |
|---|---:|---:|---|
| `smoke_test_dma_aes_gcm_short_1_dword` | 2,000 mcycles | 209.721 s | `of_LOAD_VEC4` 9.07%; `vthread_run` 3.70%; `malloc` 3.24%; `copy_from_big_` 3.01%; `vthread_schedule_list` 2.83%; `__dynamic_cast` 2.84% |
| `smoke_test_sha256` | 2,000 mcycles | 202.253 s | `of_LOAD_VEC4` 9.60%; `vthread_run` 3.79%; `copy_from_big_` 3.27%; `__dynamic_cast` 3.11%; `vthread_schedule_list` 3.00%; `eeq` 2.42% |
| `cptra_ss_test_rom` | 2,000 mcycles | 200.759 s | `of_LOAD_VEC4` 9.77%; `vthread_run` 3.68%; `copy_from_big_` 3.21%; `vthread_schedule_list` 2.95%; `__dynamic_cast` 2.78%; `eeq` 2.48% |

Across the 18-workload corpus, leading remaining samples include `send_vec4` 11.11% in `rtl_alu`; event callbacks 11.14% and `send_vec4` 8.83% in `rtl_pipe`; `vthread_run` 11.01% and `schedule_event_` 6.29% in `multi_clock`; and `yylex`/`yyparse` 12.81%/10.00% in the startup-heavy `uvm_config_factory` workload. See the saved corpus reports in the archive for each workload.

The leading Caliptra symbol remains `of_LOAD_VEC4`, a WP4 target already merged as #601. No individual remaining WP5–WP13 Caliptra profile leader reaches 10% self time. The measured smaller leaders are `copy_from_big_` (3.01–3.27%), `__dynamic_cast` (2.78–3.11%), `vthread_schedule_list` (2.83–3.00%), and `eeq` (2.42–2.48%); these are upper bounds on savings from eliminating each whole symbol, not achievable speedup predictions. Other corpus leaders are workload-specific and do not establish Caliptra throughput gains.

Job 3003 failed before measurement because its isolated input omitted `source.commit`; no samples were collected. Its output is preserved under `attempts/job-3003-preflight-failure/`. The successful rerun uses a fresh Slurm directory. The extracted archive used for local inspection is not duplicated here; the compressed artifact retains the raw profiles, reports, runs, and SHA-256 manifest.
