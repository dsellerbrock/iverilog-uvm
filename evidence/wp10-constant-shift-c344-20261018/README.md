# WP10 constant-shift lowering screen

Measurement base: `c344d20197a569dea8936bad95de3d185b1e78dc`.

Profile lead: `rtl_pipe` spends 9.94% of sampled time in `send_vec4` and
9.82% in event callbacks. Its generated netlist repeatedly expresses a
constant left shift as `.part` followed by `.concat`. This prototype lowers
only a private, zero-delay, low-part plus high-zero-pad pair to the existing
`.shift/l` instruction. Shared, named, forced, delayed, variable-part, and
width-mismatched nets stay on the existing path.

Screen gate: at least 10% fewer Callgrind instructions on `rtl_pipe`, no more
than 2% increase on any other corpus workload, and byte-identical outputs for
all 18 workloads. The pinned reference and candidate builds and all screen
results will be recorded below; no speedup is claimed until those screens
finish.

Attempt r1 is invalidated: code review found that the zero-pad matcher also
needs to reject event-synchronous constants, because their initialization
ordering is observable. Attempt r2 includes that guard; r1 results are not
used as performance or correctness evidence.

Attempt r2 did not reach source staging: the build script's candidate label
did not match its manifest. Job 2836 exited before compilation. Attempt r3
corrects that metadata mismatch; r2 is not performance or correctness evidence.

Attempt r3 reached compilation, where Slurm job 2837 found a missing closing
parenthesis in the new event-synchronous guard. The source is fixed in r4; r3
has no usable build, correctness, or performance evidence.

Attempt r4 built successfully in Slurm job 2840. The focused `rtl_pipe`
compile emitted 128 `.shift/l` nodes in the candidate and none in the
reference; the 18-workload instruction and output screen is Slurm job 2842.

## r4 interim checkpoints

The notes below were recorded while Slurm job 2842 was still running; the
final result supersedes their pending status.

The `rtl_pipe` pair in job 2842 recorded 207,775,470,868 reference versus
165,809,972,706 candidate Callgrind instructions (−20.197523%). This clears
the target instruction threshold. The two corpus groups are still running;
the regression screen and byte-identical output gate are not complete, so
this is preliminary and not a go decision.

At an intermediate checkpoint, 11/18 paired profiles had completed. The largest
non-target instruction increase among those completed was below 0.001%;
output equality and the remaining seven workloads are still pending.

The `rtl` array task has since completed successfully: all nine workloads in
that group, including `rtl_pipe`, have byte-identical outputs. The `other`
group remains in progress.

## r4 final screen

Both Slurm array groups completed with `SUCCESS`. All 18 workload outputs
match byte-for-byte. The instruction screen passes: `rtl_pipe` fell from
207,775,470,868 to 165,809,972,706 instructions (−20.197523%); the largest
non-target increase was `uvm_config_factory` at +0.000678%. The complete
per-workload table is in
[`instruction-screen.csv`](attempts/r4/results/instruction-screen.csv), and
the output-hash comparisons are in the two `corpus.json` files under
[`attempts/r4/results/screen/`](attempts/r4/results/screen/).
The 18 raw Callgrind profiles, with per-profile checksums, are preserved in
[`callgrind-profiles.tar.gz`](attempts/r4/results/callgrind-profiles.tar.gz);
the top-level artifact checksums are in
[`SHA256SUMS`](attempts/r4/results/SHA256SUMS).
Each workload used one interleaved reference/candidate pair pinned to one
CPU; this is the deterministic instruction screen, not the final wall-time
median table.

The task left `squeue` after both success markers appeared. Slurm accounting
is unavailable on this host, so a final scheduler exit code could not be
confirmed. The screen scripts' success markers and `screen=PASS` result are
the recorded evidence.
