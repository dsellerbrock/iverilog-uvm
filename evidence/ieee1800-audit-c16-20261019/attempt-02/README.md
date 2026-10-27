# IEEE 1800 Clause 16.4 probes

The five probes cover observed deferred assertion glitch suppression and stable
failure reporting, final deferred assert/cover actions in the Postponed region,
a deferred assertion item outside procedural code, and rejection of a
nonzero deferred delay and a compound deferred action block. Both
IEEE 1800-2017 and 1800-2023 are tested.

IEEE 1800-2017/2023 §16.4 defines observed deferred `#0` and final deferred
assertions, requires pass/fail actions to be a single subroutine call or null,
and permits deferred assertion items outside procedures. Final deferred
actions execute in the Postponed region; observed deferred actions are
scheduled later in the current time step. Syntax 16-2 permits only `#0` or
`final`.

Slurm job **3172** used the pinned compiler from staged source
`6604c23e197980b69a5b6b69864ff8ef8d05eba3` (Icarus 13.0-devel), 1 CPU / 1 GiB,
and a 120-second per-test timeout. `iverilog` SHA-256 is
`f8c0376ed73753c3327b1d7f5d4d647820836799064d965be7e1a8fbb9403ccd`; `vvp`
SHA-256 is
`53ad297f5370175e0df8af51c5947b7b34c723cf258617febf716cf82168249b`.

In both editions the final assert/cover system-task actions ran in the required
later region, and both negative syntax probes were rejected. The observed and
module-level probes using user-task action calls emitted `sorry` diagnostics and
were dropped. IEEE 1800-2017/2023 §16.4 permits a task call in those actions, so
this records a gap; the follow-up in `attempt-03/` separates that limitation from
the supported system-task timing paths. Full compiler/run logs are preserved
under `results/` and `logs/`.
