# IEEE 1800 §16.9.2 assertion-action follow-up

Slurm job 3178 compiled the probes with `-gassertions` under Icarus 13.0 devel
built from source `6604c23e197980b69a5b6b69864ff8ef8d05eba3` (Icarus SHA-256
`f8c0376ed73753c3327b1d7f5d4d647820836799064d965be7e1a8fbb9403ccd`; VVP
SHA-256 `53ad297f5370175e0df8af51c5947b7b34c723cf258617febf716cf82168249b`).
Each compile and simulation had a 120-second timeout.

Consecutive exact/range and the nonconsecutive-vs-goto distinction passed in
both editions. The isolated goto-positive probe failed because its testbench
asserted `c` one sampled cycle too late: it changed `c` on the negedge after
the required `##1` sample. This is a probe stimulus error, not a simulator
verdict. The corrected goto trace and rerun are in
[`attempt-09-goto-trace-correction`](../attempt-09-goto-trace-correction/).

Attempt 06 is separately preserved as a harness failure: its `cover property`
pass actions were dropped by Icarus.
