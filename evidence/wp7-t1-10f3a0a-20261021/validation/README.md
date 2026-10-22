# WP7 T1 focused candidate validation

Pinned measurement base: `10f3a0a2509d0852c2556cb6622fb0025121fb2d`. Candidate source is the frozen job3763 patch, SHA-256 `d732f301ae0abcb05dd5a3093d40f9ae40460fa0e104572a414892afcfef5db0`.

Job 3768 runs the full 18-workload JSON corpus and three Caliptra functional/tier-histogram cases, plus per-draw seeded trace comparisons for range, enum, dist, `randomize_z3`, and `randomize_dv_txn` across seeds 1, 2, 17, 42, 2026, 324508639, 610839777, and 1234567890. Its script enforces byte-identical outputs, at least 10% instruction improvement on both randomization targets, and at most 2% regression on every other corpus workload.

Job 3769 builds the candidate and runs `make check`, FPGA target install, the full ivtest JSON gate, and real-DPI UVM. It shares the same pinned base and candidate patch. Both jobs request 4 CPUs and 8 GiB. Job 3768 has an effective 2 hour 15 minute limit set with `scontrol update`; the prior r10 run took 1 hour 52 minutes 44 seconds end-to-end, and r11 adds eight seeds, so the limit is tight but measured from the same harness; job 3769 now has an effective 1 hour 40 minute limit set with `scontrol update` to fit Slurm backfill. Job 3769 completed within that limit. Stage times were 43:51.92 for ivtest and 10:44.91 for real-DPI UVM; the full job ran 57m36s.

Job 3769 passed in 57m36s: `make check`, FPGA install, 15 runtime invariants, the full JSON ivtest sweep (4,804 passed, 0 failed), and real-DPI UVM (367 passed, 0 failed, 0 skipped).

Job 3768 completed the eight-seed output comparisons and 17 corpus workloads. Its analyzer stopped because the reference `waveform_fst` process intermittently exited 139 under Callgrind. Recovery job 3798 captured two clean, byte-identical FST reference/candidate pairs; repeated SIGSEGV profiles were excluded. Recovery job 3809 completed the combined 18-workload screen and three Caliptra tier-histogram pairs on the same frozen binaries.

The final Callgrind speedups are 2.253387x for `randomize_z3` and 1.454097x for `randomize_dv_txn`; no other workload regressed by more than 2% (largest increase: `classq`, +0.026751%). Candidate tier counts were 282 T2 / 518 T3 for `randomize_z3`, 400 T4 calls for `randomize_dv_txn`, and 5,000 T0 calls for `uvm_traffic`. The focused T1 fixtures recorded 35/64 range, 40/64 enum, and 63/64 constant-`dist` calls. The three Caliptra cases had zero randomize calls in both builds; normalized functional logs and generated firmware hashes matched.

The PR includes the seeded traces and hashes, job 3809's machine-readable
corpus and tier summaries, normalized Caliptra functional logs, and job 3769's
gate provenance and stage-status summary. Raw Callgrind profiles, Valgrind
logs/executables, generated Caliptra build trees, and full gate logs remain in
the local artifact copy; no profile data was rewritten to fit source whitespace
checks. Job 3731 is not used as evidence for this candidate. The M5 10x target
remains unmet.

## Cached-hull follow-up at PR head `2a2e71b`

All follow-up measurements use the same pinned base,
`10f3a0a2509d0852c2556cb6622fb0025121fb2d`. Job 3820 rebuilt both sides and
passed the 18-workload output comparison, eight-seed replay, and 10%/2%
instruction screen. Callgrind measured 2.252988x for `randomize_z3` and
2.375035x for `randomize_dv_txn`; the largest non-target increase was
`classq` at +0.026753%. Candidate tier counts were 282 T2 / 518 T3 for
`randomize_z3`, 400 T4 calls with 350 hull-cache hits for `randomize_dv_txn`,
and 5,000 T0 calls for `uvm_traffic`. The focused range, enum, and constant
`dist` fixtures measured 2.301874x, 2.194573x, and 37.138188x respectively.
Detailed results and selected artifacts are in
[`corpus-hull-r1/README.md`](corpus-hull-r1/README.md).

Job 3820's Caliptra stage stopped before simulation because its environment
did not put the pinned OpenSSL toolchain directory on `PATH`. Job 3839 stopped
in preflight because the pinned QD-BFM path is a source directory, not a Git
checkout. Job 3841 captured 2,000-mcycle prefixes for all three Caliptra cases
on CPU 0. After stripping only heartbeat, elapsed-time, and performance-counter
lines, the prefixes and generated firmware hash lists match. These bounded
windows do not reach the tests' completion markers and are not full functional
passes; job 3809's completed Caliptra run remains the full-run evidence. Job
3822 passed the full correctness gates on this candidate:
`make check`, FPGA install, 15 runtime invariants, 7,559 passed and zero failed
in the 7,564-case JSON sweep, and 367/367 real-DPI UVM tests. Exact-head Fast
Linux CI passed on commit `2a2e71b`; it must run again after the evidence update
changes the PR head.

The cumulative 10x goal remains unmet. No seed or distribution changed and no
dependency was added.
