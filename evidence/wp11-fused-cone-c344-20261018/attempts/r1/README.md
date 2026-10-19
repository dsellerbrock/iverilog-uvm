# Attempt 1: first matcher

Measurement base: `c344d20197a569dea8936bad95de3d185b1e78dc`.
Candidate: `8f0b4ad23bf1829abbe87001bc71adcb91989712`.
Slurm job: 2827.

Both reference and candidate builds completed. The candidate compiled
`rtl_pipe`, but emitted zero `SHL_XOR_SUM` operators. Inspection of the
generated VVP showed that the constant zero pad is represented by a transparent
`BUFT` over a literal and that intermediate expressions have local `_ivl_`
signal aliases. The initial matcher recognized neither case, so no performance
screen was run and no speedup is claimed.

The exact inputs, logs, build exit code, and generated candidate VVP are kept
under this directory. The corrected matcher remains pinned to the same base.
