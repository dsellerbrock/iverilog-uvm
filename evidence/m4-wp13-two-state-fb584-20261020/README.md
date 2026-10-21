# M4 WP13: inclusive two-state execution screen

Pinned M4 measurement base: `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`.

Profile source: Slurm job 3383, commit `cc25756d187314742d347267c2a513b3e640a7fb`, on one pinned CPU over three Caliptra 2,000-mcycle windows. The runtime files that can affect this screen (`vvp/`, `libvpi/`, `vpi/`, `benchmarks/`, `configure.ac`, and `Makefile.in`) are unchanged between that profile source and the pinned M4 base. Lost perf samples: zero. Raw profiles and original symbol reports are in [job 3383](../m3-current-main-profile-cc25756-20261020/attempts/job-3383/profile-bundle.tgz); the final per-symbol parser and JSON results are under `input/job3383-inclusive/`, with reanalysis provenance in [job 3589](attempts/job-3589-inclusive-parse/README.md).

## Inclusive symbol screen

The table reports the share of weighted perf samples whose call chain contains each symbol. These inclusive rows overlap. The combined ceiling therefore uses the union of matching samples, which counts a sample once even when it passes through several listed functions. Inline symbols are shortened by `perf script`; their names below map to the corresponding `vvp_vector4_t`, signal, or net-functor implementations. Ambiguous inline names make this an optimistic screen.

| Symbol / inline helper | DMA | SHA | ROM | Removed by this prototype |
|---|---:|---:|---:|---|
| `vvp_vector4_t destructor` | 12.426% | 12.465% | 12.675% | — |
| `vvp_net_t::send_vec4` | 9.263% | 9.165% | 9.486% | — |
| `vvp_send_vec4` | 7.319% | 7.192% | 7.684% | — |
| `vec4_value (inlined; multiple signal classes)` | 6.914% | 6.963% | 6.608% | Partial* |
| `vvp_vector4_t constructor` | 5.926% | 6.766% | 7.225% | — |
| `vvp_send_vec4_pv` | 6.108% | 6.196% | 7.049% | — |
| `vvp_vector4_t::copy_from_big_` | 5.944% | 6.206% | 5.707% | Partial* |
| `recv_vec4` | 5.130% | 4.918% | 5.482% | — |
| `vvp_vector4_t::copy_from_ (inline)` | 3.992% | 4.784% | 4.189% | Partial* |
| `vvp_wire_vec4::release_pv` | 3.018% | 3.299% | 4.108% | — |
| `vvp_vector4_t::set_bit` | 3.209% | 3.409% | 2.995% | — |
| `vvp_vector4_t::allocate_words_` | 2.754% | 2.662% | 3.689% | — |
| `recv_vec4_pv` | 2.353% | 2.600% | 3.518% | — |
| `vvp_net_t::send_vec4_pv` | 2.203% | 2.394% | 3.342% | — |
| `vvp_wire_vec4::filter_vec4` | 2.699% | 2.706% | 2.468% | — |
| `vvp_vector4_t::eeq` | 2.544% | 2.768% | 2.428% | — |
| `vvp_vector4_t::mul` | 2.249% | 2.299% | 2.405% | — |
| `vvp_vector4_t::setarray` | 2.126% | 2.255% | 1.950% | — |
| `construct<vvp_vector4_t, const vvp_vector4_t&>` | 1.639% | 2.217% | 1.847% | — |
| `vvp_vector4_t::operator=` | 1.784% | 1.738% | 1.716% | Partial* |
| `vvp_vector4_t::resize` | 1.056% | 1.173% | 1.054% | — |
| `recv_vec4_` | 0.956% | 0.843% | 0.995% | — |
| `vvp_vector4 array get_word` | 0.783% | 0.757% | 0.694% | — |
| `vector4_to_value<long int>` | 0.637% | 0.584% | 0.644% | — |
| `vvp_vector4_t::add` | 0.569% | 0.541% | 0.586% | — |
| `vvp_vector4_t::set_vec` | 0.537% | 0.517% | 0.608% | — |
| `vvp_vector4_t::subarray` | 0.537% | 0.599% | 0.495% | — |
| `vvp_wire_vec4::vec4_part_value` | 0.610% | 0.445% | 0.554% | — |
| `vector4_to_value<unsigned int>` | 0.555% | 0.493% | 0.428% | — |
| `vvp_wire_vec4::filtered_value_` | 0.451% | 0.488% | 0.423% | — |
| `vpip_vec4_to_int64_saturated` | 0.414% | 0.460% | 0.423% | — |
| `_M_realloc_append<const vvp_vector4_t&>` | 0.382% | 0.345% | 0.329% | — |
| `vvp_wire_vec4::force_fil_vec4` | 0.191% | 0.201% | 0.221% | — |
| `recv_vec4_from_inputs` | 0.187% | 0.220% | 0.203% | — |
| `non-virtual thunk to vvp_fun_signal4_aa::vec4_value` | 0.132% | 0.201% | 0.212% | — |
| `do_CMPE` | 0.137% | 0.215% | 0.144% | — |
| `vvp_vector4_t::has_xz` | 0.132% | 0.148% | 0.153% | — |
| `vvp_vector4 array set_word` | 0.118% | 0.139% | 0.122% | — |
| `non-virtual thunk to vvp_wire_vec4::vec4_value` | 0.082% | 0.105% | 0.167% | Partial* |
| `vvp_vector4_t::operator&=` | 0.082% | 0.125% | 0.086% | — |
| `vvp_vector4_t::sub` | 0.086% | 0.105% | 0.081% | — |
| `destroy<vvp_vector4_t>` | 0.055% | 0.115% | 0.063% | — |
| `vvp_wire_vec4::vec4_preponed_value` | 0.082% | 0.081% | 0.059% | — |
| `recv_vec4_pv_` | 0.050% | 0.038% | 0.054% | — |
| `vvp_vector4array_t::get_word_` | 0.055% | 0.043% | 0.027% | — |
| `filter_mask_<vvp_vector4_t>` | 0.032% | 0.038% | 0.027% | — |
| `recv_vec4_base_` | 0.018% | 0.043% | 0.023% | — |
| `receive (ambiguous inline)` | 0.023% | 0.034% | 0.027% | — |
| `vvp_vector4_t::operator^=` | 0.014% | 0.024% | 0.036% | — |
| `store_qo_i<vvp_vector4_t, vvp_queue_vec4>` | 0.009% | 0.038% | 0.023% | — |
| `store_prop<vvp_vector4_t>` | 0.023% | 0.019% | 0.018% | — |
| `calculate (ambiguous inline)` | 0.023% | 0.010% | 0.027% | — |
| `compare_gtge` | 0.009% | 0.029% | 0.018% | — |
| `check_word_change` | 0.023% | 0.010% | 0.009% | — |
| `non-virtual thunk to vvp_wire_vec4::vec4_part_value` | 0.014% | 0.010% | 0.014% | — |
| `vvp_vector4_t::operator|=` | 0.014% | 0.010% | 0.009% | — |
| `is_forced` | 0.009% | 0.000% | 0.009% | — |
| `vvp_vector4array_t::set_word_` | 0.000% | 0.005% | 0.009% | — |
| `calculate_result (ambiguous inline)` | 0.000% | 0.010% | 0.000% | — |
| `copy_inverted_from_` | 0.000% | 0.005% | 0.000% | — |
| `fill_bits` | 0.000% | 0.005% | 0.000% | — |
| `vvp_vector4array_sa` | 0.005% | 0.000% | 0.000% | — |
| `__do_uninit_copy<const vvp_vector4_t*, const vvp_vector4_t*, vvp_vector4_t*>` | 0.000% | 0.000% | 0.005% | — |
| `__uninitialized_copy_a<const vvp_vector4_t*, const vvp_vector4_t*, vvp_vector4_t*, vvp_vector4_t>` | 0.000% | 0.000% | 0.005% | — |
| `__uninitialized_move_if_noexcept_a<vvp_vector4_t*, vvp_vector4_t*, std::allocator<vvp_vector4_t> >` | 0.000% | 0.000% | 0.005% | — |
| `remember<vvp_vector4_t>` | 0.000% | 0.000% | 0.005% | — |
| `uninitialized_copy<const vvp_vector4_t*, vvp_vector4_t*>` | 0.000% | 0.000% | 0.005% | — |
| `vector4_to_value<long unsigned int>` | 0.000% | 0.000% | 0.005% | — |

`—` means the prototype would keep the existing four-state behavior in that symbol. `Partial*` means only work in the source-wire `vec4_value` call on an elaborated two-state signal with no active force could use the new path; it does not remove the full symbol. The separate exact `vvp_wire_vec4::vec4_value` self shares are 0.82% (DMA), 0.70% (SHA), and 0.77% (ROM). The prototype's fast-path ceiling is lower still because it changes only the B-plane copy within that work. The prototype was rejected after the measured A/B regressed; no runtime change is retained.

The generic interpreter load/store dispatch is also substantial but is not B-plane handling and is not credited to this ceiling: its combined inclusive sample union is 25.47% (DMA), 24.92% (SHA), and 24.86% (ROM). The prior screen considered only `of_LOAD_VEC4`; this screen also accounts for arithmetic, comparisons, construction, copying, resize, and net propagation/value-change work.

| Test | Inclusive B-plane-related sample union | Ideal Amdahl ceiling if that entire union vanished |
|---|---:|---:|
| `smoke_test_dma_aes_gcm_short_1_dword` | 45.53% | 1.836× |
| `smoke_test_sha256` | 47.50% | 1.905× |
| `cptra_ss_test_rom` | 46.46% | 1.868× |
| Equal-weight three-test combined | 46.48% | 1.869× |

These ceilings deliberately assume the complete cost of every matching call-chain sample disappears. They are not expected speedups: the candidate does not touch most rows, and none of the profiles annotates a sample with the signal's declared state type. The all-`vec4_value` inclusive upper bound is only 6.61–6.96% by symbol (6.99–7.27% when thunk samples are included), or 1.075–1.078×; only a subset is a `vvp_wire_vec4` two-state source. Ambiguous inline `calculate` and `receive` names are included conservatively in the union.

## Pinned-base A/B

Slurm job 3570 built the base and candidate from `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`, then interleaved three repeats per variant and test over the fixed 100–2,100 mcycle window on pinned CPU 2.

| Test | Base median cycles/s (spread) | Candidate median cycles/s (spread) | Change |
|---|---:|---:|---:|
| `smoke_test_dma_aes_gcm_short_1_dword` | 10.537 (1.33%) | 10.408 (1.69%) | −1.22% |
| `smoke_test_sha256` | 10.566 (1.62%) | 10.511 (2.15%) | −0.52% |
| `cptra_ss_test_rom` | 10.537 (0.62%) | 10.446 (1.10%) | −0.86% |
| Three-test geometric mean | 10.547 | 10.455 | **−0.87%** |

All 39 generated firmware inputs and normalized simulation logs matched across all 18 runs. The candidate is rejected because it misses the requested +5% threshold and regresses each test. A corrected `wire bit` (`.net/2u`) narrow/wide fixture passed against the candidate, including forced X/Z fallback and release; the initial job fixture used `.var/2u` and was not sufficient by itself. Full run details are in [job 3570](attempts/job-3570/README.md).

## Type proof and prototype

`vvp_wire_vec4::two_state_` is set while elaborating a `.net/2u` as `vpiIntVar`. The prototype uses that stored type proof and takes the fast path only when the force mask is empty. It copies the A plane and writes zero to the destination B plane. If a force is active, or a wide source lacks valid plane storage, the existing four-state path runs. A `bit` variable (`.var/2u`) does not prove this path; the corrected fixture uses `wire bit` (`.net/2u`). The prototype and temporary fixture are rejected on performance and will not be retained in the runtime tree.

The only eligible path tested was `vvp_wire_vec4::vec4_value` materialization. It deliberately left arithmetic, logic, comparisons, constructors, resize, propagation, and functor value changes on the existing generic representation because `vvp_vector4_t` carries no two-state type tag through those operations.

The inclusive table is a profile-sample screen from job 3383, with its final parsing pass in [job 3589](attempts/job-3589-inclusive-parse/README.md). The per-symbol rows overlap; only the deduplicated sample union is used for Amdahl's ceiling. The candidate A/B, byte-identical log check, and corrected type-proof/X-injection fixture are complete. No runtime change advances.
