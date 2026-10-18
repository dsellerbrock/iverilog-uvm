# WP10 constant left-shift screen

Measurement base: `c344d20197a569dea8936bad95de3d185b1e78dc` (recorded in
`input/measurement-base.txt`).

This prototype targets `rtl_pipe`, where each of its 128 stages lowers the
constant expression `din << 5` to a `.part` followed by a `.concat`. The
current-main profile attributes 9.89% of samples to event-callback work and
9.89% to `send_vec4`; the part and concat functions account for smaller
individual shares. The experiment replaces the private part/concat pair with
one `.shift/l`, removing an intermediate event hop.

The rewrite accepts only a two-input regular concat with a low-order all-zero
literal, a fixed base-zero part as its other input, exact widths, no delay or
event-synchronous part behavior, and a part output nexus observed only by that
part and concat. Any named signal, additional consumer, or other connection
keeps the original nodes. The concat's own output delay is preserved. The
private semantic fixture covers 0, 1, X, and Z input bits and compares complete
stdout and stderr; it does not add or edit ivtest gold files.

Status: prototype; screening and correctness evidence pending. The acceptance
gate is at least 10% fewer Callgrind instructions on `rtl_pipe`, no more than
2% increase on any of the other 17 workloads, and byte-identical outputs on
all 18. This screen does not claim a Caliptra throughput gain.

## Evidence

- `input/semantic/`: private 4-state output comparison.
- `input/run_codegen_callgrind.py`: one-run, byte-strict screen that compiles
  each workload with both the reference and candidate front ends.
- `submit/`: isolated Slurm build and screening jobs.
- Slurm job IDs, outputs, build provenance, and result hashes will be recorded
  here without replacing earlier attempts.
