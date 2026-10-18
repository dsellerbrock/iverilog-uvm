# M3 current-main profiles

Pinned source is `ca559fd97b19bd6a56cc10f0faf8583b4077975f`, the current
`origin/main` when this profile was staged. The runtime, build, and benchmark
path diff from the previously reported throughput head `9b5fad2` is empty.

The Slurm job profiles the three Caliptra top-level tests over the fixed
mcycle window `[100, 2100]` and records one `perf record` profile per workload
in `benchmarks/sim-hotspots` (the 18-workload corpus). Simulations are pinned
to one CPU. Caliptra runs use the campaign-fixed ECC entropy input and the
same external QD-BFM and RTL revisions as the M2 throughput measurement.

Job script: [`submit/profile-current-main.sbatch`](submit/profile-current-main.sbatch)
Corpus profiler: [`input/profile_corpus.py`](input/profile_corpus.py)

## Caliptra profiles — Slurm job 2312

Each profile sampled the current-main VVP process during mcycle 100–2,100.
The default `task-clock:uppp` event produced 21K–24K samples per test with no
lost samples. The fixed window took 212.659 s for DMA AES-GCM, 206.928 s for
SHA-256, and 190.063 s for ROM. The runner's exit code 1 is expected because
the VPI marker stops each incomplete firmware test at mcycle 2,100.

| Test | `of_LOAD_VEC4` | `copy_from_big_` | `__dynamic_cast` | `eeq` | `of_PROP_INDEX_CHECK` |
| --- | ---: | ---: | ---: | ---: | ---: |
| DMA AES-GCM | 9.63% | 3.03% | 2.78% | 2.33% | 2.48% |
| SHA-256 | 9.93% | 3.08% | 3.10% | 2.35% | 2.31% |
| ROM | 9.49% | 3.39% | 2.68% | 2.55% | 2.42% |

The three profiles have a consistent interpreter stack/vector signature.
`of_LOAD_VEC4` is the largest sampled function but is a WP4 item and therefore
outside this round's authorized WP5–WP13 scope. The detailed perf reports and
compressed samples for these three runs are in
[`attempts/m3-profiles-and-reports.tgz`](attempts/m3-profiles-and-reports.tgz).

## 18-workload corpus profile — Slurm job 2322

Each workload was repeated under `perf record` until at least three seconds
had elapsed, on one pinned CPU using `task-clock:u` at 99 Hz. All 18 reports
have zero lost samples. The table shows the two largest self-sampled symbols;
these are profile leads, not instruction-count contributions.

| Workload | Samples | Largest self-sampled symbols |
| --- | ---: | --- |
| `behav` | 368 | `vvp_darray_atom<int>::get_word` 8.70%; `vector4_to_value<int>` 5.98% |
| `classq` | 571 | `__strcmp_avx2` 4.38%; `vvp_object_t` copy 3.68% |
| `fork_heavy` | 304 | `vthread_free_context` 91.78%; `vthread_s::operator new` 1.32% |
| `gate_strength` | 440 | `vvp_vector4_t::set_bit` 9.77%; `reduce4` 7.50% |
| `io_text` | 268 | `vpip_vec4_to_dec_str` 12.69%; `__strcmp_avx2` 7.09% |
| `large_memory` | 288 | `of_PUSHI_VEC4` 11.81%; `of_LOAD_VEC4` 9.38% |
| `multi_clock` | 310 | `vthread_run` 10.32%; `schedule_event_` 9.35% |
| `randomize_dv_txn` | 278 | `libz3` sample 3.24%; `__strcmp_avx2` 2.52% |
| `randomize_z3` | 365 | `libz3` sample 13.42%; `libz3` sample 10.14% |
| `rtl_alu` | 390 | `vvp_net_t::send_vec4` 14.10%; `filter_vec4` 7.44% |
| `rtl_pipe` | 825 | `vvp_net_t::send_vec4` 9.94%; `vvp_event_callback_begin` 9.82% |
| `strings_aa_queue` | 312 | `__strcmp_avx2` 9.29%; `vpip_vec4_to_dec_str` 8.01% |
| `uvm_config_factory` | 307 | `__strcmp_avx2` 10.10%; `yylex` / `yyparse` 9.77% each |
| `uvm_traffic` | 337 | `__strcmp_avx2` 4.45%; `_int_malloc` 4.15% |
| `vpi_callbacks` | 518 | `vpip_vec4_get_value` 17.57%; `vvp_event_callback_begin` 10.04% |
| `waveform_fst` | 318 | `vvp_event_callback_begin` 10.06%; `fstWriterFlushContextPrivate2` 7.23% |
| `waveform_vcd` | 283 | `vvp_event_callback_begin` 8.13%; `__printf_buffer` 7.42% |
| `wide_vectors` | 301 | `vvp_vector4_t::mul` 31.23%; `vvp_vector4_t::set_vec` 9.97% |

The corpus puts workload-specific value in automatic-context release
(`fork_heavy`), class-object/string handling (`classq`, `uvm_traffic`, and
`strings_aa_queue`), scheduler event insertion (`multi_clock`), and net
fanout/filter work (`rtl_alu`, `rtl_pipe`). Randomization and compile/load
workloads are isolated: `randomize_z3` samples libz3 heavily, while
`uvm_config_factory` samples parsing. Those do not establish a Caliptra
throughput win. In the Caliptra profiles, the recurring in-scope leads are
VPI call casts (2.68–3.10%), automatic-context resolution (2.03–2.65%),
allocator paths, and `vthread_schedule_list` (2.10–3.11%). The much larger
`of_LOAD_VEC4`/vec4-copy share belongs to completed WP4 and is excluded from
this round.

The detailed perf reports, compressed profiles, corpus summary, and job
provenance are in [`attempts/m3-profiles-and-reports.tgz`](attempts/m3-profiles-and-reports.tgz).
Its SHA-256 is `751074215f59b994aa206848be1ab8d0198434d3c90e29c9b66093cdc67094bc`.

Attempt 2312 captured all three Caliptra profiles. Corpus attempt 2312 stopped
on `rtl_pipe` because a one-shot short process produced no perf samples. Job
2317 then failed because `taskset` was given the workload name instead of the
runner command. Job 2319 confirmed the host does not support `cycles:u` and a
short default-event sample still produced no data. The current pass repeats
each workload under perf for at least three seconds, using the same
`task-clock` event that successfully sampled the longer Caliptra windows. The
job 2320 still failed before launching VVP because the profiler passed the
runner's `runtime_arguments` parameters in reverse order; the corrected
attempt uses the runner's declared `(name, runtime, plugin_dir)` order. The
failed-attempt bundles are preserved under [`attempts/`](attempts/).
