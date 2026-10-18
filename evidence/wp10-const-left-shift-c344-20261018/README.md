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

Status: rejected before performance screening. Slurm job 2803 built the
candidate, but the focused code-shape assertion failed because the rewrite did
not emit a shift. Diagnostic job 2804 confirmed the reference and candidate
outputs match for both the private fixture and `rtl_pipe`, while their VVP
shapes are identical: 3 parts/3 concats/0 shifts in the fixture and 128
parts/128 concats/0 shifts in `rtl_pipe`. No Callgrind or wall-time claim is
made. The candidate recognized a literal only through a direct constant
nexus, but elaboration represents this zero pad through a BUFT and a temporary
net; its additional “no signal observer” condition also excluded the
intermediate part net. Safely preserving those observable nets needs a broader
analysis than this screen. The captured diagnostics are in
[`attempts/job-2804/`](attempts/job-2804/).

## Evidence

- `input/semantic/`: private 4-state output comparison.
- `input/run_codegen_callgrind.py`: one-run, byte-strict screen that compiles
  each workload with both the reference and candidate front ends.
- `submit/`: isolated Slurm build, semantic, and diagnostic jobs.
- The candidate did not pass its structural gate, so the 18-workload screen
  was not run and this is not a Caliptra speedup.
