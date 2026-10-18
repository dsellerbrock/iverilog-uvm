# WP9 scheduler-list measurement

Pinned base: `d9caaaea5b410ed14e7ca14be828fc2f2c9fea44`.

Slurm job 2643 built VVP with `--enable-perf-stats` and ran the 32-clock
`multi_clock` corpus case. The time-list counter recorded 5,978,390 insertions,
6,893,806 traversed cells (1.153 per insertion on average), and a maximum
walk of 7. The instrumented simulation took 0.53 s and peaked at 12,220 KiB;
these diagnostic-build timings are not performance evidence. The archive hash,
counter JSON, timing output, build log, and Slurm script are preserved here.

The current-main profile attributes 9.35% of `multi_clock` samples to
`schedule_event_`; scheduler/context paths are 2.10–3.11% in the three
Caliptra profiles. Even eliminating the entire sampled `schedule_event_`
function cannot meet the 10% screening gate on `multi_clock`, while the actual
linked-list walk averages just over one cell. WP9 therefore has no qualifying
change from this profile, and no scheduler code was changed.
