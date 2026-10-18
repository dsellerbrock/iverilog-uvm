# M3 current-main profiles, c344d201

Measurement base: `c344d20197a569dea8936bad95de3d185b1e78dc`.

Slurm job 2783 profiled the three Caliptra firmware tests over the fixed
mcycle window `[100, 2100]`, on one pinned CPU. Each profile has zero lost
samples. The marker plug-in stopped each incomplete firmware run at cycle
2,100, so the runner's exit code 1 is expected. The exact marker rows and
generated firmware input hashes are in
[`attempts/job-2783/`](attempts/job-2783/); reports and compressed profiles
are in `m3-current-main-profile.tgz`.

## Caliptra profiles

Self-sampled VVP symbols, percent of each profile:

| Symbol | DMA AES-GCM | SHA-256 | ROM |
| --- | ---: | ---: | ---: |
| `of_LOAD_VEC4` (WP4, merged) | 9.86% | 9.89% | 10.11% |
| `vvp_vector4_t::copy_from_big_` | 3.27% | 3.28% | 3.07% |
| `__dynamic_cast` | 3.08% | 3.25% | 3.16% |
| `vthread_schedule_list` | 2.93% | 2.98% | 2.84% |
| `vvp_vector4_t::eeq` | 2.46% | 2.54% | 2.27% |
| `of_PROP_INDEX_CHECK` (WP2, merged) | 2.26% | 2.36% | 2.24% |
| `resolve_context_scope` | 2.00% | 2.19% | 2.12% |
| `vvp_vector4_t::setarray` | 2.02% | 2.08% | 2.19% |
| `vvp_net_t::send_vec4` | 1.77% | 1.62% | 1.78% |
| `vvp_vector4_t::mul` | 1.51% | 1.53% | 1.51% |

The main path ranking is stable across the three firmware tests. WP6's VPI
dispatch work addresses part of the recurring `__dynamic_cast` cost. The
strongest remaining plan candidates are WP11 (net-send and combinational
event work) and WP12 (thread scheduling); their Caliptra samples are spread
across several small symbols, so profile share alone does not establish a
25% throughput gain.

## 18-workload corpus

Job 2783 recorded each workload for at least three seconds, pinned to one CPU.
All profiles have zero lost samples, and the run and output hashes for all 18
are in `attempts/job-2783/corpus/summary.json`.

| Workload | Samples | Largest self-sampled symbols |
| --- | ---: | --- |
| `behav` | 374 | `vector4_to_value` 6.95%; `vvp_darray_atom<int>::get_word` 5.88% |
| `classq` | 572 | `__strcmp_avx2` 4.90%; `vvp_object_t` copy 3.85% |
| `fork_heavy` | 166 | `_int_malloc` 15.66%; `vthread_s` destructor 7.23% |
| `gate_strength` | 440 | `vvp_vector4_t::set_bit` 9.32%; `vvp_fun_part_sa::recv_vec4` 8.64% |
| `io_text` | 272 | `vpip_vec4_to_dec_str` 10.29%; `__strcmp_avx2` 9.56% |
| `large_memory` | 297 | `of_PUSHI_VEC4` 10.10%; `vvp_vector4_t::setarray` 8.42% |
| `multi_clock` | 309 | `vthread_run` 12.30%; `of_LOAD_VEC4` 6.47% |
| `randomize_dv_txn` | 298 | solver sample 4.36%; `__strcmp_avx2` 4.03% |
| `randomize_z3` | 400 | solver samples 15.50% and 8.50% |
| `rtl_alu` | 391 | `send_vec4` 15.35%; `filter_vec4` 7.93% |
| `rtl_pipe` | 728 | `vvp_event_callback_begin` 9.89%; `send_vec4` 9.89% |
| `strings_aa_queue` | 314 | `__strcmp_avx2` 7.64%; RTTI subtype check 5.41% |
| `uvm_config_factory` | 284 | `yylex` 13.73%; `yyparse` 8.45% |
| `uvm_traffic` | 354 | `_int_malloc` 5.93%; alias unregister 3.95% |
| `vpi_callbacks` | 511 | `vpip_vec4_get_value` 14.87%; `vvp_event_callback_begin` 13.70% |
| `waveform_fst` | 317 | `vvp_event_callback_begin` 11.04%; FST writer 6.62% |
| `waveform_vcd` | 286 | `vvp_event_callback_begin` 10.49%; binary VPI formatting 5.59% |
| `wide_vectors` | 294 | `vvp_vector4_t::mul` 38.44%; `vvp_vector4_t::copy_from_big_` 9.52% |

The sparse-multiply prototype reduced `wide_vectors` Callgrind instructions by
40.53% on c344 with byte-identical outputs, but `mul` is only 1.51–1.53% of
these Caliptra samples. It is a WP4 follow-up rather than one of the requested
WP5–WP13 packages, so it remains a screened result and is not counted toward
the M3 Caliptra target. Randomization, compile/load, and standalone vector
workloads do not establish a Caliptra speedup by themselves.

## Provenance

Job script: [`submit/profile-current-main.sbatch`](submit/profile-current-main.sbatch).
Corpus profiler: [`input/profile_corpus.py`](input/profile_corpus.py).
Source, profile outputs, raw reports, and logs are preserved under
`attempts/job-2783/`; the archive SHA-256 is recorded in
`attempts/job-2783/LOCAL-SHA256SUMS`.
