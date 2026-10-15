# A2 Caliptra top-level regression profile

Pinned A5 measurement base: `c7ebca768c21c251d9c165c9aff0e363768030b1`.

This diagnostic sampled A2's M7 row `smoke_test_dma_aes_gcm_short_1_dword`,
reported at 7.023 cycles/s on c339 versus 6.384 cycles/s on current main
(ratio 0.9090). The archived QD-BFM input is `d1529c922da402943148a0fb22648f347e30eed9`; the supervisor's note cites
`5f15a13`, so this sample has a visible provenance mismatch.

Callgrind was too slow for Caliptra, so both builds were sampled with
`perf record` over matching mcycle windows and identical firmware hashes:

| Window | c339 | Current main | Change |
| --- | ---: | ---: | ---: |
| mcycle 100–600 (500 cycles) | 65.801 s, 7.599 cycles/s | 66.104 s, 7.563 cycles/s | main 0.5% slower |
| mcycle 100–5000 (4,900 cycles) | 630.605 s, 7.770 cycles/s | 630.012 s, 7.778 cycles/s | main 0.094% faster |

The 100–600 window collected about 9,000 samples per side; the longer window
collected 64K task-clock samples per side. Both had zero lost samples and
about 1.85 GB peak RSS. Neither sample reproduces the full-row slowdown.
Sampled inclusive shares in the longer window were `of_LOAD_VEC4` 12.81%
(c339) versus 13.44% (main), `of_PROP_INDEX_CHECK` 13.74% versus 10.58%, and
`vpip_vec4_to_int64_saturated` 10.16% versus 9.12%. These are diagnostic
samples, not whole-test timing evidence.

An earlier 3,600-second Callgrind attempt stopped at mcycle 525 and produced
no valid profile. Full logs and raw profiles remain in the local A5 evidence
archive; this PR retains the paired-window summary and input revisions.
