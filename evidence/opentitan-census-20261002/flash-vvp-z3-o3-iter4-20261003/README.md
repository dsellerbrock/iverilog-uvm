# Z3 solver `-O3` experiment (iteration 4/5)

## Candidate

The saved Flash Time Profiler captures include `z3_solve_pass_` and related solver frames during randomized constraint solving. This experiment compiled only `vvp/vvp_z3.cc` with `CXXFLAGS=-g0 -O3`; the other VVP object files remained at `-O2`.

## Same-workload Flash replay

The replay used the same host, Flash image, DPI library, test, sequence, plusargs, default seed, and 1,200-second / 10,000,000,000-byte RSS envelope as the prior runs. No `+ntb_random_seed` was supplied; the output reports `DefaultSeed=0xa8cee782` and `DefaultSeedLocal=0x219b79a0`. Image SHA-256: `4b25c822438e9553e50454a188f53a031f9261f212e8692f3e83aae0ba848260`. DPI SHA-256: `b77b12c4c2ff467faf5ec324affdd5e588bcb1de61f4a1ab1a951463565794eb`.

The run hit the wall cap at 1,200.5 seconds; peak RSS was 1,200,898,048 bytes. Its last checked event was the same operation 2/3 bank-1 `FlashPartData` erase at 1,414,652.8 ns. No later checked operation, PASS, UVM error, or UVM fatal appeared. The solver-only native build therefore established no end-to-end speedup.

The runtime was rebuilt at `-O2` after the experiment (SHA-256 `2dee1367fb1c984aa8e77d58ddd6f87808b39489d2862fe9bf03e78f1739f570`). Iteration counter is 4/5; the 60-minute fallback gate and full 49-target corpus remain pending.

Artifacts: `run-flash-1200s-10gb.py`, `flash.log`, `progress.jsonl`, and `result.json`.
