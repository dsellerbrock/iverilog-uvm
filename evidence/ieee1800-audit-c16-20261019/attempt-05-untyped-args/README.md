# IEEE 1800 §16.8 untyped-formal follow-up

This isolates untyped sequence formal arguments from the typed-formal syntax
failure in attempt 04. IEEE 1800-2017 and 1800-2023 §16.8 Syntax 16-5 permit
formals without an explicit type; the test uses the formals in a sequence
instance from a concurrent assertion.

Slurm job 3175 used Icarus 13.0 devel built from source
`6604c23e197980b69a5b6b69864ff8ef8d05eba3` (Icarus SHA-256
`f8c0376ed73753c3327b1d7f5d4d647820836799064d965be7e1a8fbb9403ccd`; VVP
SHA-256 `53ad297f5370175e0df8af51c5947b7b34c723cf258617febf716cf82168249b`).
Both `-g2017` and `-g2023` compile and run with `PASSED`, each invocation
capped at 120 seconds. Raw compiler/run outputs, compiler identity, and the
Slurm transcript are preserved in this directory. Slurm did not retain a
reliable elapsed-time field for this short completed job.
