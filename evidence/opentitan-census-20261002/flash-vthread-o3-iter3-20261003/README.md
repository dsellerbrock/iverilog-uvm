# VVP interpreter `-O3` experiment (iteration 3/5)

## Candidate

The native Time Profiler call trees repeatedly sampled `vthread_run` and its fork/task execution paths. This experiment rebuilt only `vvp/vthread.cc` with `CXXFLAGS=-g0 -O3`; the other VVP translation units remained at the normal `-O2`. An earlier one-million task-call stress reducer had measured the `-O3` binary at about 4-5% slower than `-O2`, but no full Flash application measurement had been made.

## Same-workload Flash replay

The replay used the same host, Flash image, DPI library, test, sequence, plusargs, default seed, and 1,200-second / 10,000,000,000-byte RSS envelope as the prior run. The command did not supply `+ntb_random_seed`; output reports `DefaultSeed=0xa8cee782` and `DefaultSeedLocal=0x219b79a0`. Image SHA-256: `4b25c822438e9553e50454a188f53a031f9261f212e8692f3e83aae0ba848260`. DPI SHA-256: `b77b12c4c2ff467faf5ec324affdd5e588bcb1de61f4a1ab1a951463565794eb`.

The replay hit its 1,200-second wall cap at 1,200.6 seconds; peak RSS was 1,304,969,216 bytes, well under the cap. The last checked event was operation 2/3's bank-1 `FlashPartData` erase at 1,414,652.8 ns, exactly matching the prior run. No later checked operation, PASS, UVM error, or UVM fatal appeared. No end-to-end speedup was established.

The `-O2` VVP runtime was restored (SHA-256 `5737616f59fbcd305e1c9baf340acd5983050c42d9024702ed632611e29ca523`). Iteration counter is now 3/5; the 60-minute fallback gate and full 49-target corpus remain pending.

Artifacts: `run-flash-1200s-10gb.py`, `flash.log`, `progress.jsonl`, and `result.json`.
