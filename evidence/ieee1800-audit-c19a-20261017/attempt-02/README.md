# Clause 19 bisection attempt 02 — one invalid generated variant

Slurm job 2256 tested a copy with the default-bin array declaration replaced
by an inline comment and a second copy with it changed to a single default
bin. The inline comment swallowed the covergroup's closing brace, so that
variant's compile errors are a probe-generation mistake and are not behavior
evidence. The single-default variant was valid: it compiled and ran in both
editions. It passed all checks except the two output-argument checks, which
reported `n=0,d=0`; scalar coverages were 7.142857% and 33.333333%.

Raw output and both generated sources are preserved beside this note. Attempt
03 removes only the declaration cleanly and is the valid bisection result.
