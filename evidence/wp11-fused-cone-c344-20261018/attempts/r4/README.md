# Attempt 4: BUFT pin-count correction

Measurement base: `c344d20197a569dea8936bad95de3d185b1e78dc`.
Candidate patch marker: `wp11-buft-pin-count-fix`.
Slurm build job: 2830; reference and candidate builds completed.

The API counts the output pin, so this attempt changed the matcher’s BUFT
check from two pins to three. The generated `rtl_pipe.vvp` still contains zero
`SHL_XOR_SUM` functors. The job stopped at the emission guard (exit 1), before
the performance or output screen. Dependent screen job 2832 was canceled.

The candidate VVP, patch, logs, and result marker are preserved here. No
performance result is claimed.
