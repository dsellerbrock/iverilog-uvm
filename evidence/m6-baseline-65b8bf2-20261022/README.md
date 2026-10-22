# M6 Caliptra baseline

Measurement base: `65b8bf2045dfa7a66120bb8c81d8941e97d6daaa` (pinned once for M6).

`input/run_m6_baseline.sh` checks out that exact source commit and its pinned submodules, runs three interleaved samples of each of the three Caliptra top-level tests over mcycle 100–2,100, profiles one fixed-window sample per test with `perf record`, and runs the 18-workload Callgrind corpus. The benchmark build uses `-g -O2 -fno-omit-frame-pointer`; any candidate comparison must use the same flags. The Caliptra runs use fixed ECC entropy and compare normalized logs and generated `.hex` manifests across repeats.

The Callgrind reference and candidate wrappers intentionally use the same baseline `vvp`; this establishes baseline counts and checks that the corpus harness outputs are byte-identical. Callgrind raw files are discarded after the 18-row count table is produced.

The main CI run on this SHA is a gate for accepting the result. The baseline may run while CI is in progress; if this SHA fails CI, re-pin and rerun.

Pinned-base CI passed: GitHub `main test` workflow 39834960544 completed with exit 0 on exact head `65b8bf2045dfa7a66120bb8c81d8941e97d6daaa`. Its Ubuntu, macOS, and Windows jobs are all green, so this baseline remains valid on the pinned base.

## Runner correction after job 4225

Job 4225 built the pinned source and reached the exact 100–2,100 mcycle window on the DMA test. It stopped at a harness assertion: the VPI window plugin calls `vpiFinish(0)`, so `vvp` correctly exited 0 while the full-top runner returned 1 because the firmware test was intentionally incomplete. The runner now checks that expected exit pair and the absence of a firmware finish marker. No throughput or profile result from job 4225 is accepted. The fetched diagnostic files and hashes are in [the failure evidence](failures/job-4225/MANIFEST.sha256).

## Candidate preselection from existing profiles

- **Prior profiles select no qualifying candidate yet.** On post-WP6 main `cae0356`, the largest remaining Caliptra self samples were `copy_from_big_` 3.01–3.27%, `__dynamic_cast` 2.78–3.11%, `vthread_schedule_list` 2.83–3.00%, and `eeq` 2.42–2.48%. The larger `of_LOAD_VEC4` share (9.07–9.77%) is the already-merged WP4/#601 optimization. No individual remaining WP5–WP13 hotspot reached the 10% screen.
- **WP6 is already merged as #658** (VPI dispatch); it reports no Caliptra speedup. Residual dynamic-cast samples are below the target threshold and do not justify repeating that package without new M6 evidence.
- **WP11 and WP12 are closed with no runtime candidate.** M4 found no eligible fused cone; the prior MUXZ prototype changed a named-net delta trace. Process fusion had no repeated trigger sets in the measured `multi_clock` workload, and `vthread_run` was only 3.25–3.65% on Caliptra.
- **WP9 is rejected by the scheduler counters.** All three Caliptra windows recorded zero time-list walk steps, despite about 316 million insertions per test.
- **WP13 is closed and excluded.** M4's inclusive 4-state screen gave a 1.869× ideal ceiling, but its type-proven prototype regressed Caliptra by 0.87%; do not reopen it in M6.
- **Other prior exclusions:** WP5 call frames were 0.02–0.03% of Caliptra samples; WP7 is closed from M5 and Caliptra makes zero `randomize()` calls; WP8 is startup-only; WP10 had no eligible emitted shape. The 5.7–6.2% inclusive `copy_from_big_` share was not mapped to a remaining WP and is not itself a candidate.

The M6 profile may reveal a different eligible target on the new base. If not, the recorded prior screens show that the remaining packages do not yet support a 10% Caliptra candidate; do not advance a package from corpus-only shares.

## Job 4323: baseline and early close-out

Pinned source: `65b8bf2045dfa7a66120bb8c81d8941e97d6daaa`. GitHub `main test` workflow 39834960544 passed on this exact SHA. Slurm job 4323 built that source with `-g -O2 -fno-omit-frame-pointer`, pinned the Caliptra runs to one CPU, interleaved three samples per test over mcycle 100–2,100, and recorded one fixed-window `perf` profile per test. All three profiles report zero lost samples. Each test's three normalized logs and generated-hex manifests matched.

| Caliptra test | Median cycles/s (spread) | Logs / generated hex |
| --- | ---: | --- |
| `smoke_test_dma_aes_gcm_short_1_dword` | 11.076984 (2.978%) | Identical / identical |
| `smoke_test_sha256` | 11.153798 (0.730%) | Identical / identical |
| `cptra_ss_test_rom` | 11.167282 (0.644%) | Identical / identical |
| Three-test geometric mean | 11.132617 | — |

The corresponding +25% target is 13.915771 cycles/s. No remaining WP5–WP13 candidate has a supported +3% cycles/s projection, so no candidate A/B was run and M6 closes at the baseline. Raw self shares are not treated as fully removable work. This is a close-out of the screened paths, not a claim about a global VVP ceiling.

### Top ten Caliptra self-sample shares

`perf report --stdio --no-children -g` rankings; mean is the arithmetic mean of the three per-test self shares.

| Hotspot | DMA | SHA-256 | ROM | Mean |
| --- | ---: | ---: | ---: | ---: |
| `of_LOAD_VEC4` | 8.72% | 9.15% | 9.15% | 9.01% |
| `vvp_vector4_t::copy_from_big_` | 3.60% | 3.69% | 3.51% | 3.60% |
| `vthread_run` | 3.38% | 2.98% | 3.24% | 3.20% |
| `malloc` | 2.77% | 2.76% | 2.66% | 2.73% |
| `vvp_vector4_t::eeq` | 2.81% | 2.51% | 2.75% | 2.69% |
| `__dynamic_cast` | 2.50% | 2.78% | 2.68% | 2.65% |
| `vvp_vector4_t::setarray` | 2.47% | 2.61% | 2.56% | 2.55% |
| `cfree` | 2.67% | 2.36% | 2.58% | 2.54% |
| `_int_malloc` | 2.34% | 2.75% | 2.48% | 2.52% |
| `of_PROP_INDEX_CHECK` | 2.39% | 2.50% | 2.41% | 2.43% |

### Candidate decisions

| Candidate | Why it is below the +3% bar |
| --- | --- |
| `of_LOAD_VEC4` follow-up | The 8.72–9.15% symbol is already covered by merged WP4/#601. The only type-proven follow-up screened in WP13 measured −0.87% geometric-mean cycles/s, so the large symbol share is not a measured remaining gain. |
| `copy_from_big_` / two-state vector path (WP13) | The fresh self share is 3.51–3.69%, but the candidate A/B regressed all three Caliptra tests (−1.22% DMA, −0.52% SHA-256, −0.86% ROM). The 1.869× inclusive Amdahl ceiling is not a candidate projection. |
| `vthread_run` fusion or scheduling (WP11/WP12) | Its 2.98–3.38% self share is not removable work by itself. WP11's four prototype builds emitted zero fused operators; WP12 found no eligible identical-trigger process group. |
| Allocator / stack-slot reuse (`malloc`, `cfree`, `_int_malloc`, `setarray`) | Each listed symbol is 2.34–2.77% self share. The callgraphs place some `malloc` under `PUSHI_VEC4`/`MULI` construction and `_int_malloc` under `vthread_new_` deque setup, but do not isolate a reusable stack-slot path. `allocate_words_` is 1.56–1.65% and `operator delete[]` 0.29–0.39%, at most 2.04% combined (2.08% ideal cycles/s gain if both vanished); `cfree` is not attributed to stack-slot reuse. WP5's measured Caliptra free path was only 0.02–0.03%. No evidence-based ≥3% projection is available. |
| `eeq`, `__dynamic_cast`, `of_PROP_INDEX_CHECK` | Their largest individual shares are 2.81%, 2.78%, and 2.50%. Even removing each whole symbol gives ideal cycles/s gains of only 2.89%, 2.86%, and 2.56%, respectively. |

| WP | M6 disposition |
| --- | --- |
| WP5 | Merged #640; its Caliptra free path is 0.02–0.03%. |
| WP6 | Merged #658; no Caliptra speedup or new VPI hotspot in this top ten. |
| WP7 | Merged #828; these Caliptra tests make zero `randomize()` calls. |
| WP8 | Screened; parser/compile work is outside the steady-state cycle window. |
| WP9 | Screened; zero time-list walk steps across about 316 million insertions per test. |
| WP10 | Screened; the required emitted constant-shift shape is absent. |
| WP11 | Screened; no fused operators, and the earlier MUXZ prototype changed a named-net delta trace. |
| WP12 | Screened; no eligible identical-trigger group. |
| WP13 | Rejected; type-proven prototype measured −0.87% geometric mean. |

The three closest residual leads are the already-merged load path, un-attributed allocator cost, and `vthread_run`; none has a qualifying projection. They are recorded for context only, not queued as speculative WPs.

Job 4323 ended with exit 1 in the separate 18-workload Callgrind pass: `waveform_fst-01-candidate` exited 139, so the 18-row corpus table and success archive were not produced. The Caliptra throughput and profile outputs above were already complete. The fetched summaries, compressed `perf.data`, corpus failure JSON, logs, and hashes are in [job 4323 evidence](job-4323/MANIFEST.sha256). Because the valid top-ten triggers the early-stop rule, the corpus workload was not rerun and no WP was started.
