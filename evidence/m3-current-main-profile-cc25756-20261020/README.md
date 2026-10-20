# M3 current-main profile refresh

Pinned source: `cc25756d187314742d347267c2a513b3e640a7fb` (`origin/main`, refreshed 2026-10-20). Slurm job 3383 built this exact commit with four CPUs and 8 GiB, then profiled each simulation on one pinned CPU (CPU 12) with `perf record -F 99 -g --call-graph fp`, perf 7.0.14, Intel Core Ultra 9 285K. The job completed with exit 0 and zero lost samples in all 21 profiles.

## Caliptra windows

Each profile covers mcycle 100–2,100 (2,000 mcycles). The fixed-window runner intentionally exits 1 after the stop marker; the script checked the marker and nonempty perf data before recording a profile. Elapsed time is the wall time to reach that window, not cycles/s throughput.

| Test | Elapsed to window | Top self samples |
| --- | ---: | --- |
| `smoke_test_dma_aes_gcm_short_1_dword` | 196.960 s | `of_LOAD_VEC4` 9.39%; `vthread_run` 3.65%; `copy_from_big_` 3.49%; `__dynamic_cast` 3.02% |
| `smoke_test_sha256` | 187.584 s | `of_LOAD_VEC4` 9.04%; `copy_from_big_` 3.70%; `vthread_run` 3.25%; `__dynamic_cast` 2.83%; `of_PROP_INDEX_CHECK` 2.72% |
| `cptra_ss_test_rom` | 200.694 s | `of_LOAD_VEC4` 9.32%; `vthread_run` 3.41%; `copy_from_big_` 3.30%; `__dynamic_cast` 2.98% |

These are sampling shares, not before/after speedups. `of_LOAD_VEC4` is the largest individual share but is below the 10% screening threshold on its own; the next Caliptra candidate must reduce related load/copy work together and be measured on instructions. The converter optimized in #601 does not appear among these top Caliptra symbols.

## 18-workload corpus

Each corpus workload ran for at least three seconds. Percentages are top self samples from `perf report --no-children`; the report rows below are for hotspot selection, not speed claims.

| Workload | Top self samples |
| --- | --- |
| `behav` | `vvp_darray_atom<int>::get_word` 8.31%; `of_LOAD_VEC4` 6.43% |
| `classq` | `__strcmp_avx2` 3.61%; `vvp_cobject::set_vec4` 3.26% |
| `fork_heavy` | `register_live_ptr_` 12.14%; `vthread_s::operator new` 7.86% |
| `gate_strength` | vec4 copy constructor 9.09%; `set_bit` 8.86% |
| `io_text` | `vpip_vec4_to_dec_str` 12.88%; `__strlen_avx2` 9.09% |
| `large_memory` | `of_LOAD_VEC4` 9.93%; `as_signal_value` 7.53% |
| `multi_clock` | `vthread_run` 15.65%; `of_LOAD_VEC4` 7.35% |
| `randomize_dv_txn` | `__strcmp_avx2` 4.58%; `_int_malloc` 3.17% |
| `randomize_z3` | unresolved library addresses 12.43%, 9.67% |
| `rtl_alu` | `send_vec4` 11.73%; `filter_vec4` 8.42% |
| `rtl_pipe` | `send_vec4` 11.48%; event callback begin 8.61% |
| `strings_aa_queue` | decimal conversion 8.04%; `__dynamic_cast` 6.43% |
| `uvm_config_factory` | `yylex` 12.77%; `sym_get_value` 7.80% |
| `uvm_traffic` | `unregister_signal_alias` 6.23%; `_int_malloc` 5.34% |
| `vpi_callbacks` | callback begin 15.02%; callback end 9.15% |
| `waveform_fst` | callback begin 9.12%; FST flush 8.14% |
| `waveform_vcd` | callback begin 10.80%; VCD format 7.32% |
| `wide_vectors` | `vvp_vector4_t::mul` 30.61%; `multiply_with_carry` 10.54% |

## Experiment order

After WP7, screen the Caliptra load/copy path first: the profile consistently puts `of_LOAD_VEC4` at 9.04–9.39%, with `copy_from_big_` at 3.30–3.70%. Treat this as a candidate only; the single load symbol cannot clear the 10% gate by itself. Keep `send_vec4`/callback work for RTL corpus targets, and allocation/alias work for class-heavy workloads. The profile does not support a new converter or scheduler-queue experiment for the Caliptra target. The earlier Gemini multipliers remain unverified Amdahl projections.

Raw profiles, reports, test logs, pinned-source provenance, and checksums are in `attempts/job-3383/`; the profile bundle SHA-256 is `aa62aa7636682a850619a269b556e66276839f71d897fc1673316cd0639cbe0e`.
