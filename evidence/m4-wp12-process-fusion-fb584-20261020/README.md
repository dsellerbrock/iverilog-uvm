# M4 WP12: process-fusion screen

Pinned M4 measurement base: fb584a251dd4cc91e56a75be662ccd5ee05c64e9.

Profile source: Slurm job 3383 on cc25756d187314742d347267c2a513b3e640a7fb, pinned to one CPU, with three 2,000-mcycle Caliptra windows and all 18 corpus workloads. VVP scheduling and thread-loop sources are unchanged between the profile source and the M4 pin.

## Profile and eligibility

The largest scheduler-related corpus row is multi_clock: vthread_run accounts for 15.65% of samples. Its 32 generated always blocks each wait on a different posedge clock net, and the clock generators use distinct delays. The fixture therefore has no repeated trigger set to fuse. The earlier WP12 screen measured only 0.65% in vthread_schedule_list for multi_clock.

Caliptra vthread_schedule_list shares were 2.84–3.00% in the recent current-main profile series, below the 10% screen. The current cc25756 profile does not list the scheduler among the top Caliptra symbols.

## Decision

No identical-trigger process group with a 10% target share was identified. No process-fusion candidate or performance claim was advanced. See the source fixture benchmarks/sim-hotspots/multi_clock.sv and the earlier detailed screen at evidence/wp12-process-fusion-c344-20261018/README.md.
