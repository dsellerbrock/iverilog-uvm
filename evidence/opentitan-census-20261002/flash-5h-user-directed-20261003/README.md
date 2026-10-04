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
In its 7,263-frame call tree, `randomize_with_` appears in 1,377 frames (about
19%), `z3_enumerate_sparse_wide_domain_` in 744 (about 10%), and VVP's
`of_VPI_CALL` in 1,393 (about 19%). The same sample contains
`sva_enabled_calltf`, `sva_kill_generation_calltf`, VPI iteration, and value
access. These are stack sample counts from one interval, not exclusive CPU
shares or a total-run breakdown. The sample confirms solver and VPI/SVA work
are both active at this later point.

Two later captures during the 3/3 group (`flash-sample-operation3-40m.txt` and
`flash-sample-followup-4.txt`) show a similar mix: about 18% of sampled stacks
enter `randomize_with_`, about 14% enter the sparse-domain enumeration helper,
and about 16% enter `of_VPI_CALL`. The randomization subtree reaches repeated
Z3 solver/model calls; the VPI subtree includes the SVA enabled, kill-generation,
and clock callbacks. `flash-sample-operation4-53m.txt` and
`flash-sample-operation4-61m.txt` show a different, much larger hot path: in the
61-minute capture, 7,596 of 7,691 sampled stacks are under
`of_AA_NEXT_SIG_V`, and the flat symbol summary records 7,023 samples in
`compare_vec_keys_`. These are profiler sample counts, not direct elapsed-time
percentages. A third capture at 75 minutes (`flash-sample-operation4-75m.txt`)
still shows 7,563 of 7,656 stacks under `of_AA_NEXT_SIG_V`, with 6,870 flat
samples in `compare_vec_keys_`. An automatic capture at 86 minutes
(`flash-sample-followup-5.txt`) independently confirms the same path: 7,533 of
7,656 stacks under the associative-array opcode and 6,753 flat comparator
samples.

The VVP image maps this opcode in
`flash_ctrl_env_cfg.check_partition_mem_model()` to the loop over
`scb_flash_model[addr]`. That loop checks each expected word with a backdoor
`read32`. The data model is a 32-bit-address associative array. Its setup loop
inserts 131,072 words per bank across two banks, or 262,144 entries for the data
partition. In `vvp/vvp_assoc.h`, vector-key `next_key_()` scans the full map and
uses `compare_vec_keys_()` to choose each successor. Repeating that scan for
every entry makes a full traversal quadratic in the number of stored addresses.
The source mapping and operation4 samples make this the strongest measured
explanation for the long final memory-check phase. The 53-, 61-, and 75-minute
samples did not show the scope lookup walk as a hot path; the earlier VPI scope
cache remains in the runtime, but these captures do not quantify an end-to-end
speedup from it.

The active `vvp/vvp` is already a native Mach-O ARM64 executable built with
`-O2 -g0`; it links the native Z3 dylib. The SystemVerilog image is VVP
bytecode dispatched by native runtime opcode functions. Rebuilding those same
functions with more aggressive compiler flags may help smaller costs, but it
cannot remove the measured whole-map scan. The associative-array successor
algorithm is the high-value optimization target.

`capture-followup-samples.py` scheduled additional low-overhead samples while
the replay ran. `sample-progress.jsonl` and `sample-result.json` record which
captures completed.

## Final result

The replay exited normally after 5,349.4 seconds (89m 9s), below the five-hour
wall cap. Peak RSS was 1,748,877,312 bytes, below the 10,000,000,000-byte cap.
All seven operation starts were recorded, the log ended with `TEST PASSED
CHECKS`, and the UVM report summary shows zero errors and fatals. The initial
`clean_checked_pass` value was a false negative: its classifier treated the
summary rows `UVM_ERROR : 0` and `UVM_FATAL : 0` as failures. The classifier
now checks actual `UVM_ERROR @` / `UVM_FATAL @` reports, and the stored result
was re-evaluated from the completed log. It is a clean pass.

## Comparison

The previous 60-minute replay stopped at 3,600.4 seconds, used 1,742,995,456
bytes peak RSS, reached the 4/4 operation sequence, and did not emit a checked
PASS marker. See
[`flash-60m-user-directed-fallback-20261003/README.md`](../flash-60m-user-directed-fallback-20261003/README.md).
