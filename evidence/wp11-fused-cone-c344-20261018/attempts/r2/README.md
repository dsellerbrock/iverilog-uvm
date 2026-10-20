# Attempt 2: transparent pad and local aliases

Measurement base: `c344d20197a569dea8936bad95de3d185b1e78dc`.
Candidate: `84c5627b009cd553bc54d6b60c85639a79a7053c`.
Slurm job: 2828; build completed, emitted-functor assertion failed (exit 1).

The matcher recognized the `BUFT`-backed zero pad and compiler-local `_ivl_`
aliases. It still emitted zero `SHL_XOR_SUM` operators on `rtl_pipe`. No
performance or output screen ran. Inputs, logs, and the generated VVP file
are preserved in this directory.
