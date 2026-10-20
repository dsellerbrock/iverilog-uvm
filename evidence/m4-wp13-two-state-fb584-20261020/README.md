# M4 WP13: two-state execution screen

Pinned M4 measurement base: fb584a251dd4cc91e56a75be662ccd5ee05c64e9.

Profile source: Slurm job 3383, main cc25756d187314742d347267c2a513b3e640a7fb, one pinned CPU, three Caliptra windows of 2,000 mcycles, and all 18 corpus workloads. Between that profile source and the M4 pin, the scheduler, VVP thread loop, signal-copy implementation, and vector implementation are unchanged. The intervening runtime changes are in class-object constraint tracking and randomization; Caliptra made no randomization calls in the measured corpus.

## Caliptra profile ceiling

| Test | of_LOAD_VEC4 self samples | Ideal ceiling if every of_LOAD_VEC4 sample vanished |
| --- | ---: | ---: |
| smoke_test_dma_aes_gcm_short_1_dword | 9.39% | 1.104x |
| smoke_test_sha256 | 9.04% | 1.099x |
| cptra_ss_test_rom | 9.32% | 1.103x |

These are sampled-CPU Amdahl ceilings, not measured speedups. A two-state path could affect only a subset of the generic vec4 loads, so its ceiling is lower. copy_from_big_ contributes 3.30–3.70% self samples, but the profile does not identify what portion comes from type-proven two-state sources.

## Source boundary and decision

The runtime's explicit signal proof is the `two_state_` flag set for `vpiIntVar` net declarations in `vvp/words.cc`. The flag changes the write filter: `vvp_wire_vec4::filter_vec4` converts driven X/Z bits to zero. It does not change the signal storage or read ABI: both `bits4_` and `force4_` are `vvp_vector4_t`, and `%load/vec4` obtains `vvp_signal_value` through `as_signal_value()` then calls the same virtual `vec4_value()` for either state type. That read copies `bits4_` and overlays forced bits. A force bypasses the normal two-state filter, so a forced X/Z must continue through the four-state overlay.

The profile does not separate the force-safe two-state subset from generic vec4 loads, so its exact eligible share is unknown. The measured `of_LOAD_VEC4` share is only an upper bound: 9.04–9.39% of all samples, with ideal full-symbol-removal ceilings of 1.099–1.104x. A type-specific path can affect no more than that measured load share, and the current code provides no separate two-state read implementation to screen without changing the vector storage or bytecode/stack path. The available profile and implementation therefore do not justify a candidate under the 10% gate.

No runtime candidate was advanced, and no output or seeded value changed. Since no fast path was implemented, no X-injection mutation test was run; forced X remains on the existing four-state overlay path. The recorded ceiling is a screen of the profiled load hotspot, not a global ceiling for all possible two-state execution designs.
