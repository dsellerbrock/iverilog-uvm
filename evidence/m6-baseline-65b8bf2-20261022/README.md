# M6 Caliptra baseline

Measurement base: `65b8bf2045dfa7a66120bb8c81d8941e97d6daaa` (pinned once for M6).

`input/run_m6_baseline.sh` checks out that exact source commit and its pinned submodules, runs three interleaved samples of each of the three Caliptra top-level tests over mcycle 100–2,100, profiles one fixed-window sample per test with `perf record`, and runs the 18-workload Callgrind corpus. The benchmark build uses `-g -O2 -fno-omit-frame-pointer`; any candidate comparison must use the same flags. The Caliptra runs use fixed ECC entropy and compare normalized logs and generated `.hex` manifests across repeats.

The Callgrind reference and candidate wrappers intentionally use the same baseline `vvp`; this establishes baseline counts and checks that the corpus harness outputs are byte-identical. Callgrind raw files are discarded after the 18-row count table is produced.

The main CI run on this SHA is a gate for accepting the result. The baseline may run while CI is in progress; if this SHA fails CI, re-pin and rerun.

Pinned-base CI passed: GitHub `main test` workflow 39834960544 completed with exit 0 on exact head `65b8bf2045dfa7a66120bb8c81d8941e97d6daaa`. Its Ubuntu, macOS, and Windows jobs are all green, so this baseline remains valid on the pinned base.

## Runner correction after job 4225

Job 4225 built the pinned source and reached the exact 100–2,100 mcycle window on the DMA test. It stopped at a harness assertion: the VPI window plugin calls `vpiFinish(0)`, so `vvp` correctly exited 0 while the full-top runner returned 1 because the firmware test was intentionally incomplete. The runner now checks that expected exit pair and the absence of a firmware finish marker. No throughput or profile result from job 4225 is accepted. The fetched diagnostic files and hashes are in [the failure evidence](failures/job-4225/MANIFEST.sha256).

## Candidate preselection from existing profiles

- **Prior profiles select no qualifying candidate yet.** On post-WP6 main `cae0356`, the largest remaining Caliptra self samples were `copy_from_big_` 3.01–3.27%, `__dynamic_cast` 2.78–3.11%, `vthread_schedule_list` 2.83–3.00%, and `eeq` 2.42–2.48%. The larger `of_LOAD_VEC4` share (9.07–9.77%) is the already-merged WP4/#601 optimization. No individual remaining WP5–WP13 hotspot reached the 10% screen.
- **WP6 is already merged as #658** (VPI dispatch); it reports no Caliptra speedup. Residual dynamic-cast samples are below the target threshold and do not justify repeating that package without new M6 evidence.
- **WP11 and WP12 are closed with no runtime candidate.** M4 found no eligible fused cone; the prior MUXZ prototype changed a named-net delta trace. Process fusion had no repeated trigger sets in the measured `multi_clock` workload, and `vthread_run` was only 3.25–3.65% on Caliptra.
- **WP9 is rejected by the scheduler counters.** All three Caliptra windows recorded zero time-list walk steps, despite about 316 million insertions per test.
- **WP13 is closed and excluded.** M4's inclusive 4-state screen gave a 1.869× ideal ceiling, but its type-proven prototype regressed Caliptra by 0.87%; do not reopen it in M6.
- **Other prior exclusions:** WP5 call frames were 0.02–0.03% of Caliptra samples; WP7 is closed from M5 and Caliptra makes zero `randomize()` calls; WP8 is startup-only; WP10 had no eligible emitted shape. The 5.7–6.2% inclusive `copy_from_big_` share was not mapped to a remaining WP and is not itself a candidate.

The M6 profile may reveal a different eligible target on the new base. If not, the recorded prior screens show that the remaining packages do not yet support a 10% Caliptra candidate; do not advance a package from corpus-only shares.

This is a screening order, not a speedup claim. The fresh baseline's top ten sample shares select the target; its Callgrind screen decides whether a candidate advances.
