# WP6 VPI fast paths

Pinned measurement base: `ca559fd97b19bd6a56cc10f0faf8583b4077975f`.

The combined candidate keeps `vpiIntVal` conversion in the existing 32-bit
helper and replaces three trailing RTTI checks in `vpip_execute_vpi_call` with
return-kind virtual dispatch. The initial generic-handle cast remains.
The signed-temporary predecessor was rejected after review; the corrected
unsigned-only screen and gates are retained in
[`wp6-vpi-intval-u32`](../wp6-vpi-intval-u32-ca559-20261018/README.md), with the
rejected predecessor in [`wp6-vpi-intval`](../wp6-vpi-intval-ca559-20261018/README.md).

The combined build passed (Slurm job 2602). The 18-workload Callgrind screen
passed: `vpi_callbacks` improved 14.052199%, and the largest increase was
0.303236% on `waveform_vcd`; every workload's output was byte-identical. The
FST Callgrind process returned signal 11 during writer-thread shutdown, on both
the candidate and, in isolated retry 2611, the reference. Its completed profile
summaries are preserved. Three pinned, interleaved plain-runtime pairs in job
2612 confirmed identical FST and stdout bytes; the FST Callgrind count was
14,172,749,439 reference versus 14,194,733,385 candidate (+0.155114%). See the
[18-row table](attempts/callgrind-2603/instruction-counts.csv) and the
[profiler note](attempts/callgrind-2603/SCREEN-NOTES.md).

Pinned-base combined correctness gates passed in Slurm job 2613: VPI semantic
comparison, `make check`, FPGA install, legacy (7,477 total; 0 failed), VPI
(133/133), negative (152/152), runtime invariants (15/15), JSON (4,718/4,718),
and real-DPI UVM (367/367). The detailed logs and hashes are under
`attempts/gates-2613/`. These gates are pinned to `ca559`; the required
post-rebase remeasurement and final-head checks remain. No final wall-time
claim is made yet.
