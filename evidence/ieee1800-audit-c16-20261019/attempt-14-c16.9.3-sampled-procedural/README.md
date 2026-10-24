# IEEE 1800 §16.9.3 `$sampled` procedural snapshot probe

Checks that `$sampled(value)` remains the current time step's sampled value
when called twice in the same clocked procedure with a blocking assignment
between the calls. The source is compiled and run under `-g2017` and `-g2023`
with assertions enabled and 120-second per-process timeouts.

## Slurm job 3184 result

On compiler source `6604c23e197980b69a5b6b69864ff8ef8d05eba3` (Icarus SHA-256
`f8c0376ed73753c3327b1d7f5d4d647820836799064d965be7e1a8fbb9403ccd`), both
`-g2017` and `-g2023` printed two `GAP: $sampled changed within the time
step` lines. The probe uses one clocked process: it records `$sampled(value)`,
changes `value` with a blocking assignment, and asks `$sampled(value)` again
before leaving the time slot. The function returned the changed live value.
