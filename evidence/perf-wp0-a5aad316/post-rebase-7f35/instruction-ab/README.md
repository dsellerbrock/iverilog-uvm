# WP0 post-rebase instruction-count A/B

Campaign pinned base: `f9f8e0a79f230f38da6cbb4445994ad1075ad531`.
Deliberate post-rebase measurement base: `7f35ca38c86723ab40e6ebfe9fd77259827e23f9`.
Candidate: `1174ea06ac5e3a926b1fa1c1bd3449a396507272`.

This run uses the base and stats-off candidate builds from the matching full-gates
run, compiles one shared `behav.sv` program with the candidate compiler, and
profiles both runtimes using Callgrind with seed `73014`. The campaign-pinned
base is `f9f8e0a79f230f38da6cbb4445994ad1075ad531`; this follow-up measurement
base is `7f35ca38c86723ab40e6ebfe9fd77259827e23f9` and candidate source is
`1174ea06ac5e3a926b1fa1c1bd3449a396507272`.

Job 1182 counted 94,600,024,298 reference instructions and 94,600,024,572
candidate instructions (+274, or +0.000000290%). Stdout and stderr are
byte-identical, as are all eight selected hot-path function-node counts; the
CSV and compressed profiles are in [`job1182`](job1182/). The profiles' stored
SHA256 values were verified after decompression. The Slurm wrapper returned 1
after profiling because its final `sha256sum` glob included the `results/work`
directory; the profile stage itself completed successfully. The saved
reproduction script now hashes regular files only.
