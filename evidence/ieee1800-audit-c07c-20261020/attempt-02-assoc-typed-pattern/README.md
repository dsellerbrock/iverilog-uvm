# Corrected associative-array probe

Attempt 1 exposed only a test-source issue: an untyped assignment pattern was passed directly to `exists()`. This retry uses a typed `U` variable as the key. The scope and expected semantics are documented in the parent attempt's README. Inputs are frozen in a fresh Slurm run directory; Icarus 13.0-devel `cc25756d1`, binary SHA-256 values recorded in the Slurm output. Both editions use 30-second command timeouts.
