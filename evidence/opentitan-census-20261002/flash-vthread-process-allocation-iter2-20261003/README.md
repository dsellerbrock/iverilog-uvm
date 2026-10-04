# Flash process-object allocation experiment (iteration 2/5)

## Candidate and focused checks

The prior Flash Time Profiler samples showed `vthread_run`/`do_fork_` as hot execution paths. In `do_fork_`, a synchronous task or named-block child is marked `is_fork_v_child`; `process::self()` resolves through its parent. The experiment avoided constructing a private `vvp_process` for those non-process child frames. Four focused regressions passed: process identity, synchronous-call behavior, process status, and detached-fork disable.

A 1,000,000-call task microbenchmark passed with the checked result 499999500000. Five-run median changed from 1.127636s to 1.085342s (3.75% faster), below the 10% significance threshold.

## Same-workload Flash replay

The replay used the same host, runtime image, DPI library, test, sequence, arguments, default seed, and 1,200-second / 10,000,000,000-byte RSS envelope as the prior Flash run. It did not provide `+ntb_random_seed`; the log reports `DefaultSeed=0xa8cee782` and `DefaultSeedLocal=0x219b79a0`. The image SHA-256 is `4b25c822438e9553e50454a188f53a031f9261f212e8692f3e83aae0ba848260`; the DPI SHA-256 is `b77b12c4c2ff467faf5ec324affdd5e588bcb1de61f4a1ab1a951463565794eb`.

The 1,200-second wall cap was reached at 1,200.8 seconds; peak RSS was 1,407,877,120 bytes, below the cap. The last comparable checked milestone remained operation 2/3's bank-1 `FlashPartData` erase at 1,414,652.8 ns, exactly matching the prior run. At forced shutdown, the log recorded `noOutstandingReqsAtEndOfSim_A` at 2,024,558.0 ns and `TEST FAILED CHECKS`; there was no clean PASS. That shutdown output is not treated as a successful later Flash milestone.

No 10% end-to-end gain was established. The experimental code was removed, and the O2 baseline runtime was rebuilt (SHA-256 `5737616f59fbcd305e1c9baf340acd5983050c42d9024702ed632611e29ca523`). Iteration counter is now 2/5. The 60-minute fallback gate and full 49-target corpus remain pending.

Artifacts: `run-flash-1200s-10gb.py`, `flash.log`, `progress.jsonl`, and `result.json`.
