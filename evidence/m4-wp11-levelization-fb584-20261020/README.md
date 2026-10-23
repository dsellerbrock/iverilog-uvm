# M4 WP11: combinational-cone levelization screen

Pinned M4 measurement base: fb584a251dd4cc91e56a75be662ccd5ee05c64e9.

Profile source: Slurm job 3383 on cc25756d187314742d347267c2a513b3e640a7fb, pinned to one CPU, with three 2,000-mcycle Caliptra windows and all 18 corpus workloads. The VVP net propagation and scheduling files are unchanged between the profile source and the M4 pin.

## Profile and semantic constraint

In rtl_alu, send_vec4 accounts for 11.73% self samples and filter_vec4 for 8.42%. These are self-sample shares, not inclusive cone costs. WP11 in this round only permits levelization inside an eligible fused group; WP12 found no identical-trigger groups in the profiled multi_clock target and no Caliptra scheduler share above the 10% screen.

The prior MUXZ-chain prototype emitted 64 operators and passed exhaustive four-state value checks, but changed the value-change trace of the named y net in muxz_chain_delta.sv. That violates the current hard stop on event-semantic changes. The prototype was rejected before performance measurement.

## Decision

No side-effect-free cone inside an eligible fused group was identified. No levelization candidate or performance claim was advanced. See evidence/wp11-muxz-chain-cae-20261019/README.md for the rejected trace and artifacts.
