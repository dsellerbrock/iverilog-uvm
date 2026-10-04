# Flash 60-minute fallback replay

The user directed us to skip optimization iteration 5 after iterations 1–4 showed no significant end-to-end gain, and run this 3,600-second replay. It used the restored `-O2` VVP runtime, the same Flash image, DPI library, arguments, and default seed as the prior comparable replays.

## Result

The replay hit the 3,600-second wall cap after 3,600.4 seconds. It did not emit `TEST PASSED CHECKS`, so it is not a clean PASS and the 49-target corpus was not started. The wrapper terminated VVP at the wall limit; VVP returned 0, but `timed_out=true` and `clean_checked_pass=false`. No `TEST FAILED CHECKS`, `UVM_ERROR`, or `UVM_FATAL` marker was present in the captured log.

Peak RSS was 1,742,995,456 bytes (about 1.74 GB), below the 10,000,000,000-byte cap; the RSS limit was not hit.

The run completed the initial 3-operation sequence and then advanced into a subsequent 4-operation sequence. The log records starts for operations 1/4 through 4/4; the last start was at 5,622,051.9 ns. The last scoreboard marker flushed before termination was at 5,622,434.9 ns. This is well beyond the previous 1,414,652.8 ns operation-2 milestone, but it is not a PASS.

## Next focused diagnosis

A plausible cost hotspot is repeated full-memory backdoor preparation, but this run did not time that phase separately. In `flash_ctrl_rand_ops_base_vseq.sv`, each operation calls `flash_ctrl_prep_mem` when `do_tran_prep_mem` is enabled. That invalidates the selected partition before the transaction. `flash_mem_bkdr_init(FlashMemInitInvalidate)` walks each bank and calls `mem_bkdr_util::invalidate_mem`, which loops over every word and calls `write`/`uvm_hdl_deposit`; it then rebuilds the scoreboard partition model by reading the partition words back with `read32`. The operation-4 log confirms both `FlashPartData` banks were invalidated. Earlier profiling observed about 131,000 `read32` calls per bank during model population.

Measure the time and VPI call counts for invalidation and model population separately on the next focused replay. This is a hypothesis based on the source path and run markers, not a proven complete root cause. Keep the existing memory checks intact.

## Reproduction and fingerprints

Run wrapper: [`run-flash-3600s-10gb.py`](run-flash-3600s-10gb.py).

- Test: `flash_ctrl_base_test` / `flash_ctrl_smoke_vseq`
- Default seed: `0xa8cee782`; local seed: `0x219b79a0`
- VVP SHA-256: `2dee1367fb1c984aa8e77d58ddd6f87808b39489d2862fe9bf03e78f1739f570`
- Flash image SHA-256: `4b25c822438e9553e50454a188f53a031f9261f212e8692f3e83aae0ba848260`
- DPI library SHA-256: `b77b12c4c2ff467faf5ec324affdd5e588bcb1de61f4a1ab1a951463565794eb`
- Wall cap: 3,600 seconds; RSS cap: 10,000,000,000 bytes

Artifacts: [`result.json`](result.json), [`progress.jsonl`](progress.jsonl), and [`flash.log`](flash.log). The result JSON records `clean_checked_pass: false`; continue focused diagnosis and do not start the full corpus until Flash passes with zero semantic/runtime debt.
