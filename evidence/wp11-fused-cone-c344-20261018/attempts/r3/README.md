# Attempt 3: matcher diagnostic

Measurement base: `c344d20197a569dea8936bad95de3d185b1e78dc`.
Candidate patch marker: `diagnostic-r3`.
Slurm job: 2829; paired builds completed, emitted-functor assertion failed
(exit 1).

Temporary compiler diagnostics showed that the sum, XOR, concat, and part
nodes were found, but `fused_zero_constant_width` returned `zero_ok=0` for the
pad. The assertion therefore stopped the run before any performance screen.
This isolated the rejected predicate to the BUFT constant path; the next
attempt corrects the BUFT pin-count check based on the target API's pin
convention. The temporary debug code is preserved only in this attempt's
candidate patch and was removed from the active source.
