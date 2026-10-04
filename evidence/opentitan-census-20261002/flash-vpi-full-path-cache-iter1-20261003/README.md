# Flash VPI full-path cache experiment (iteration 1/5)

## Candidate

The post-scope-cache profile showed `find_scope` in 23.8% of sampled stacks.
The candidate added a bounded 4,096-slot direct-mapped cache for successful
`(starting scope, complete path)` lookups. It retained the existing traversal
and per-segment cache on misses. Nine existing VPI scope/name regressions passed
with the candidate.

The 20,000-lookup repeated-path microbenchmark improved from a 4.567 ms median
before the candidate to 2.466 ms after it (46.0% faster). This did not translate
to the application workload.

## Same-workload Flash replay

The baseline was the preceding 1,200-second replay in
`../flash-vpi-scope-cache-20261003/`; the candidate used the same host, Flash
runtime image, DPI library, test, plusargs, default random seed, and 10 GB RSS
limit. Neither command supplies `+ntb_random_seed`; both logs report the same
OpenTitan `DefaultSeed` (`0xa8cee782`, local `0x219b79a0`) and the same two
randomized operation IDs.

Both runs reached the same final checked marker at 1,414,652.8 ns: the bank-1
Data-partition erase in operation 2/3. Neither produced a PASS, UVM_ERROR, or
UVM_FATAL marker. The candidate therefore showed no measurable simulated-time
throughput gain at the 1,200-second wall limit. Peak RSS was 1,266,155,520 bytes
for the candidate and 1,250,607,104 bytes for baseline; neither hit the 10 GB
cap.

Candidate runtime SHA-256: `c46a20badc0d1c766f98f66d1863fe977fa9adc89a8fc4a110564faadac3aa81`.
Flash image SHA-256: `4b25c822438e9553e50454a188f53a031f9261f212e8692f3e83aae0ba848260`.
DPI library SHA-256: `b77b12c4c2ff467faf5ec324affdd5e588bcb1de61f4a1ab1a951463565794eb`.

Because the end-to-end workload showed no gain, the candidate implementation
was removed. The experiment counts as iteration 1/5, with no significant
speedup. The counter remains below the 60-minute fallback gate.

Artifacts: `run-flash-1200s-10gb.py`, `progress.jsonl`, `result.json`, and
`flash.log`.
