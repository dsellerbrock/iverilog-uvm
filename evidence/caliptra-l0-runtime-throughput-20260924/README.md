# Caliptra Icarus L0 runtime sizing

The exact-52 four-job diagnostic run at `evidence/caliptra-icarus-l0-patched-52-20260924/` was deliberately stopped after one completed `smoke_test_veer` pass. It has **no aggregate verdict**. The other running first-cohort cases were still in the released firmware's `_start` `.data` copy loop at PC `0x4a`–`0x56`, before `main`; they were progressing, not hung. Their 1,800-second wall limit could not reach the test body, so this partial run must not contribute a 52-case passing rate.

| Case | `.data` bytes in linker map | Five-instruction copy-loop estimate | Last retired instruction at stop |
| --- | ---: | ---: | ---: |
| `smoke_test_mbox` | 14,332 | 17,915 | 2,560 |
| `smoke_test_mbox_byte_read` | 14,184 | 17,730 | 2,570 |
| `smoke_test_sha512` | 14,280 | 17,850 | 2,577 |
| `smoke_test_sha512_restore` | 14,592 | 18,240 | 1,005 |

The first three VVP processes ran for about 24 minutes, reaching only 14–15% of the startup-copy instruction estimate. At that measured four-job rate, startup alone would take roughly 2.7–2.9 hours; runtime after `main` remains unknown. A three-second macOS sample of the mailbox VVP main thread is preserved in [`mbox-vvp-sample.txt`](mbox-vvp-sample.txt): 230/234 samples were in `schedule_simulate`, 178/234 under `vthread_run`, and only one in log formatting. This points to full-top event/thread cost rather than trace-file I/O. The JTAG server thread was blocked in `select` as expected.

A separate single-job `smoke_test_mbox` pilot now runs the same bundled-BFM, `-gcommercial-unsafe`, reset/checker/JTAG-port-copy profile with a 14,400-second wall limit. Its result at `evidence/caliptra-icarus-l0-mbox-long-pilot-20260924/` will determine a measured timeout and throughput for the next full cohort. No pinned source or L0 checker changed.
