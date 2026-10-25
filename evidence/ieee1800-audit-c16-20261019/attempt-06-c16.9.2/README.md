# IEEE 1800 §16.9.2 probe-harness attempt (not a semantic result)

Slurm job 3176 used Icarus 13.0 devel from staged source
`6604c23e197980b69a5b6b69864ff8ef8d05eba3` for both editions. All three files
compiled, but their `cover property` action blocks were explicitly diagnosed
as dropped by Icarus (`the pass statement of this cover property is not
executed ... it is dropped`). The zero user-variable counters therefore do
not establish that the repetition sequences failed to match. Treat this run as
a harness failure, not a simulator gap.

The following attempt changes the pass/fail instrumentation to assertion action
blocks, which is the pattern used by the project's SVA tests, and checks that
every property attempt completed before reporting a result.

Raw compiler logs preserve the dropped-action warnings; runtime logs preserve
the resulting counter failures. Do not use job 3176 to classify §16.9.2.
