# IEEE 1800 §§14.10–14.11 rerun on staged batch compiler

The earlier job 3166 built the baseline at `c31cbf1b52f1a39d5775f276e2340525a444a79e`.
This repeat runs the same probe sources against the pinned compiler from the
current T2 stage, `6604c23e197980b69a5b6b69864ff8ef8d05eba3`, to confirm whether
the observed cycle-delay behavior persists on the current candidate. It uses
1 CPU, 1 GiB, and a 120-second timeout for every compile and simulation.

IEEE 1800-2017 §14.11 says an integral expression cycle delay is positive, but
separately specifies bare `##0`: before the clocking event it suspends until the
event; after the event it does not suspend. IEEE 1800-2023 §14.11 allows
non-negative expression delays and gives the same special `##0` behavior.
Both editions require an error when no default clocking exists and prohibit
cycle delays in intra-assignment delays.

Slurm job **3171** used Icarus 13.0-devel from staged source
`6604c23e197980b69a5b6b69864ff8ef8d05eba3` (1 CPU / 1 GiB; 120-second
per-test timeout). `iverilog` SHA-256 is
`f8c0376ed73753c3327b1d7f5d4d647820836799064d965be7e1a8fbb9403ccd`; `vvp`
SHA-256 is
`53ad297f5370175e0df8af51c5947b7b34c723cf258617febf716cf82168249b`.

Both editions pass the clocking-event wait, ordinary cycle-delay probe,
`##0` after the clocking event, and the two required compile rejections. Both
editions violate the pre-event `##0` rule: execution continues at 2 ns instead
of suspending until the event at 5 ns. Under 2017, `##(0)` also compiles even
though §14.11 requires expression-valued delays to be positive, and then fails
to suspend. Under 2023, `##(0)` is permitted but likewise fails to suspend.
The complete per-edition output is in `results/` and `logs/`.

Input SHA-256:

| Probe | SHA-256 |
| --- | --- |
| `p14_10_clocking_event.sv` | `2c19bb6722578c69086fb2326a254f167d537a12bfe558890a3a06364a6a9c99` |
| `p14_11_cycle_delay.sv` | `7d031f71e0899d014a5d2c3d3b60fdb3d8b69e680789bf031ad58b9c87f1c01a` |
| `p14_11_zero_cycle_delay_after_event.sv` | `90abf614c169ee68e37b68f1edce56010dc3339ff4b78defb01c42f1edbb5992` |
| `p14_11_zero_cycle_delay_bare.sv` | `3aca275718a89b6bb51a1a85c12c2b78d67278f0f02b7affae0f243f7bcefa3d` |
| `p14_11_zero_cycle_delay_expr.sv` | `c0c775c506752eacd8cf6196cf3463208139f2de626d41ae4fb62e56df45f53d` |
| `neg/n14_11_intra_assignment_delay.sv` | `cc0ba3c08158c53b24b57abe120cb43a93dca5748096e04f732e5333a0765321` |
| `neg/n14_11_no_default_clocking.sv` | `0545f0f8aff46eeea3434b1a6e978e5a8d752d3d254de3e92d3a56c9b743c6b1` |
| `run.sbatch` | `7d7e769cbb6fb2a322a115f19b7aa53bda145dadc7b1c79a8e8d02d598a25871` |
