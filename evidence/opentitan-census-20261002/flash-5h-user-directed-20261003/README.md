# Flash five-hour user-directed replay

This replay follows the user's request for a five-hour Flash timeout. It keeps
the same binary, VVP image, DPI library, command arguments, and default seed as
the 60-minute run, changing only the wall-clock limit from 3,600 to 18,000
seconds. The exact command is captured in `run-flash-18000s-10gb.py`.

## Inputs and limits

- Test: `flash_ctrl_base_test` / `flash_ctrl_smoke_vseq`
- Default seed from the previous run: `0xa8cee782`; local seed: `0x219b79a0`
- VVP SHA-256: `2dee1367fb1c984aa8e77d58ddd6f87808b39489d2862fe9bf03e78f1739f570`
- Flash image SHA-256: `4b25c822438e9553e50454a188f53a031f9261f212e8692f3e83aae0ba848260`
- DPI SHA-256: `b77b12c4c2ff467faf5ec324affdd5e588bcb1de61f4a1ab1a951463565794eb`
- Wall cap: 18,000 seconds
- RSS cap: 10,000,000,000 bytes

## Live measurement

The run started at approximately `2026-10-04 04:55:48 UTC`. The wrapper
records RSS and log size every 30 seconds in `progress.jsonl`. Redirected VVP
output remains buffered while the process runs, as in the previous unwrapped
replay; the previous five-point profiling wrapper used `stdbuf` to make output
visible live. This run keeps the prior command unchanged and uses native
process samples for live diagnosis.

An early 10-second macOS `sample` capture is in `flash-sample-early.txt`. In
that 7,142-frame slice, `randomize_with_` appeared in 1,715 frames (about 24%),
and `z3_enumerate_sparse_wide_domain_` in 981 (about 14%). The nested stack
continues through `z3_solve_pass_`, `Z3_solver_get_model`, and Z3 model
construction. The VVP process was using one CPU and about 1.2 GB RSS at the
time. This is direct evidence of a constraint-solving hot phase, not a
measurement of total run time by phase.

The test's sequence randomizes `flash_op` and `flash_op_data` in
`flash_ctrl_rand_ops_base_vseq.sv`. `flash_op.addr` is a 32-bit field, and the
hard constraint restricts it to `[0:FlashSizeBytes-1]`. A likely trigger for
the sampled sparse-domain probe is this large dense address range: the helper
tries to prove a complete set by making up to 65 solver/model queries, then
falls back when it sees more than 64 feasible values. The sample cannot identify
which property caused a particular helper invocation, so this field-to-sample
mapping remains a source-backed hypothesis until a property-level solver trace
confirms it.

A second 10-second sample at about 16 minutes is `flash-sample-followup-2.txt`.
It contains both `sva_enabled_calltf` / VPI iterator and value operations, and
continued `z3_solve_pass_` / Z3 solver-check work. This supports phase variation
across the run; it does not isolate the share of total wall time for either
path.

`capture-followup-samples.py` schedules additional low-overhead samples while
the replay runs. `sample-progress.jsonl` and `sample-result.json` record which
captures completed. The run's final status, output, peak RSS, and last
simulation progress marker will be added here after it exits.

## Comparison

The previous 60-minute replay stopped at 3,600.4 seconds, used 1,742,995,456
bytes peak RSS, reached the 4/4 operation sequence, and did not emit a checked
PASS marker. See
[`flash-60m-user-directed-fallback-20261003/README.md`](../flash-60m-user-directed-fallback-20261003/README.md).
