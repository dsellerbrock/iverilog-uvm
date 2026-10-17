# Caliptra top-level throughput, item 11

Pinned campaign base: `f9f8e0a79f230f38da6cbb4445994ad1075ad531`. The original two-way run used main snapshot `7f508a8a3ab4f1a230d65abfa2543a12ca2f40a9`. Main later advanced to `631b7a869faaa05216d8749224520227b4b23d43` while #601 CI was running. The current three-way comparison below uses that main snapshot and the exact #601 evidence head `3b620c5ea5857ba7c022a7fba058f8a31b7ac564`, which adds documentation to the measured candidate code. The PR code is unchanged from `51987d3cccfe2ddb862eb01b9a7388eb687276c6`.

The Slurm run measured three full-top-level Caliptra firmware tests at mcycle 100–2,100 (2,000 cycles), one process at a time on CPU 0. Three repeats were interleaved; repeat 2 reversed base/main order. The test runner intentionally stops at mcycle 2,100, before each firmware test completes, so these are fixed-window throughput measurements, not firmware pass results.

The base and main VVP builds used identical external inputs: QD-BFM `d1529c922da402943148a0fb22648f347e30eed9`, Caliptra RTL `49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e`, adams-bridge `b77e3d899e828d626cfc2a0d26a6b5704cc121e0`, and UVM Core `78c06547a2a0a29b3dc9dcafae62b75b2ff61544`. Build installs were created from the recorded source archives in Slurm job 1788 and reused read-only by job 1815. Job 1815 requested 1 CPU and 3 GiB. Each run used a VPI mcycle marker to record elapsed monotonic time and stop the simulator.

| Test | Base median cycles/s | Main median cycles/s | Base spread | Main spread | Main vs base |
|---|---:|---:|---:|---:|---:|
| `smoke_test_dma_aes_gcm_short_1_dword` | 7.436 | 8.211 | 11.17% | 19.45% | +10.43% |
| `smoke_test_sha256` | 7.544 | 8.844 | 11.21% | 21.74% | +17.24% |
| `cptra_ss_test_rom` | 7.762 | 8.194 | 7.29% | 11.10% | +5.57% |

Three-test geometric-mean speedup: **+10.98%**. Equal-window pooled throughput: **7.578 → 8.406 cycles/s (+10.92%)**. Spreads are high and are reported as supporting evidence; they do not block the instruction-count gate.

All 39 generated `.hex` inputs matched across every sample after using the campaign-fixed ECC entropy source (SHA-256 `c13c7c8ddf1e45b590a66b3dd64fdb01bffe7fd7c16453693435a7a28343f28d`). Simulator logs matched byte-for-byte after excluding only `MCYCLE_WINDOW` and `CALIPTRA_PROGRESS_HEARTBEAT` instrumentation lines. Each bounded run returns runner exit 1 and `passed=false` because `vpiFinish` deliberately stops the incomplete firmware test; this is expected and is not a correctness pass.

Job 1815's original analyzer stopped on the dynamic heartbeat line. The post-processor at [`analyze-fixed.py`](results/job-1815-fixed/analyze-fixed.py) rechecked all 18 fixed windows, all input hashes, the expected early-stop status, and the normalized log equality; its SHA-256 is recorded alongside it. The resulting table is [`summary.md`](results/job-1815-fixed/results/summary.md).

## Current-main comparison including the #601 candidate

Slurm job 2018 completed with exit code 0 on DAN-DESKTOP. It built the exact
campaign base, main snapshot, and #601 evidence head, then interleaved three
repeats for each test on CPU 0. Every sample covers the fixed 2,000-mcycle
window 100–2,100. Spread is `(max − min) / median`.

| Test | Campaign base f9f8e0a cycles/s (spread) | Main 631b7a8 cycles/s (spread) | #601 candidate cycles/s (spread) | Candidate vs base | Candidate vs main |
|---|---:|---:|---:|---:|---:|
| `smoke_test_dma_aes_gcm_short_1_dword` | 7.269 (1.67%) | 8.396 (2.35%) | 9.530 (0.35%) | +31.10% | +13.51% |
| `smoke_test_sha256` | 7.267 (0.66%) | 8.328 (1.13%) | 9.507 (2.34%) | +30.83% | +14.15% |
| `cptra_ss_test_rom` | 7.262 (7.50%) | 8.290 (2.06%) | 9.499 (4.13%) | +30.81% | +14.57% |

Three-test geometric-mean speedups: main vs base **+14.76%**; #601 candidate
vs campaign base **+30.91% cumulative**; #601 candidate vs current main
**+14.08%**. Equal-window pooled medians were 7.266, 8.338, and 9.512 cycles/s.
All 39 firmware `.hex` inputs and normalized simulator logs matched across all
27 samples. The VPI marker stops the tests at mcycle 2,100 before firmware
completion, so these are bounded throughput results, not firmware pass
results. Each test's base/candidate/main orders were interleaved and rotated.

Raw data, input and binary hashes, logs, and exact job inputs are in
[`results-bundle.tgz`](results-bundle.tgz).

## Attempts

- Job 1787: OOM during a four-worker build under a 3 GiB cap; no samples.
- Job 1788: both exact-source builds completed; a post-build check used an unavailable system `python3.12`; no samples.
- Job 1794: all 18 windows completed, but randomized ECC vectors differed across variants and repeats; invalid and excluded.
- Job 1815: fixed-entropy ECC inputs, 18 windows complete, and post-processed successfully as described above.

Each failed attempt and its raw logs are preserved under [`results/`](results/).
