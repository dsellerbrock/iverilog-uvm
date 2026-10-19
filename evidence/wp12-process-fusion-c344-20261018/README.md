# WP12 process fusion screen

Measurement base: `c344d20197a569dea8936bad95de3d185b1e78dc`.

## Decision

No WP12 candidate was built. The current profile does not establish an
eligible process-fusion target for the 10% screen.

## Profile evidence

Slurm job 2783 profiled the three Caliptra workloads over mcycle `[100, 2100]`
and the 18-workload corpus. In Caliptra, `vthread_schedule_list` accounts for
2.84–2.98% of samples across the three tests. This is below the 10% target
screen, and only bounds the scheduler-list portion of a possible fusion win.

The largest scheduler-related corpus row is `multi_clock`, where
`vthread_run` is 12.30% of samples. Its fixture has 32 generated clocks; each
`always @(posedge clk)` process is sensitive to a different clock net, and
each clock-toggle process has a distinct delay. Therefore the identical-
sensitivity condition in WP12 does not apply to the dominant processes. The
profile attributes only 0.65% to `vthread_schedule_list` on this workload;
the dominant interpreter-loop cost is outside the proposed fusion.

## Result

WP12 process fusion is not advanced on this profile. No generated code,
simulation output, or performance claim changed. This screens out the
`multi_clock` candidate; it does not rule out fusion on a future profile that
identifies a substantial group of NBA-only processes sharing one sensitivity.
