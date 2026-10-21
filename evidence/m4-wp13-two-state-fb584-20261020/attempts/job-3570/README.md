# WP13 pinned-base A/B, Slurm job 3570

Pinned measurement base: `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`.
Candidate patch SHA-256: `2c23a8574b3d6eeb8eaca3a6a60b2f45cc005bdc9877944997c11fee98f3f0a0`.

The reference and candidate were built independently from the pinned base. Three interleaved repeats per variant and test used the fixed mcycle window 100–2,100 (2,000 mcycles), pinned to CPU 2. `summary.json` was produced from all 18 runs; all 39 generated firmware inputs and normalized simulator logs matched. The marker intentionally stops each incomplete firmware test at mcycle 2,100; these are bounded throughput samples, not full test passes. Harness exit 1 is expected for that stop.

| Test | Base median cycles/s (spread) | Candidate median cycles/s (spread) | Change |
|---|---:|---:|---:|
| `smoke_test_dma_aes_gcm_short_1_dword` | 10.537 (1.33%) | 10.408 (1.69%) | −1.22% |
| `smoke_test_sha256` | 10.566 (1.62%) | 10.511 (2.15%) | −0.52% |
| `cptra_ss_test_rom` | 10.537 (0.62%) | 10.446 (1.10%) | −0.86% |
| Three-test geometric mean | — | — | **−0.87%** |

The job's first focused fixture used `.var/2u` and did not exercise the `vvp_wire_vec4` fast path. After the job completed, a corrected narrow/wide `wire bit` fixture emitted `.net/2u`, passed with the candidate binary, injected forced X/Z and checked the four-state fallback, then verified release restored the driven value. All raw job logs, result files, and run logs are in [`artifacts.tgz`](artifacts.tgz); original Caliptra job inputs are in [the input bundle](../../input/caliptra-job-inputs.tgz).

The candidate is rejected: the geometric mean is below the requested +5% landing threshold and all three tests are slightly slower. The runtime patch and temporary fixture were reverted after recording this result; the saved patch and test outputs remain here for review.
