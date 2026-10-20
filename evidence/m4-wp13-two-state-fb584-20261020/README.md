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

The runtime's explicit signal proof is the two_state_ flag set for vpiIntVar net declarations. Its normal signal filter converts X/Z to zero. Force writes store their values separately and bypass that filter; reads overlay the forced value. Any specialized path would therefore have to use the ordinary four-state read while a force is active. The general VVP thread stack and load opcode still carry vec4 values.

The profile does not separate the force-safe two-state subset from generic vec4 loads, so it cannot demonstrate a 10% eligible share. No runtime candidate was advanced, and no output or seeded value changed. Since no fast path was implemented, there is no new X-injection mutation test to report; forced X remains on the existing four-state read path.
