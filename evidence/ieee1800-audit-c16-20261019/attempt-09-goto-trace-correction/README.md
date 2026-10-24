# IEEE 1800 §16.9.2 goto repetition probe, corrected trace

This rerun corrects the testbench stimulus from attempt 08. After the second
sampled `b`, it raises `c` on that same falling edge, so `c` is high at the
next sampled rising edge required by `b[->2] ##1 c`. The earlier failure was
therefore a stimulus error, not a simulator verdict.

The probe is compiled and run separately with `-g2017` and `-g2023`, with
assertions enabled. Each compiler and simulation invocation has a 120-second
timeout. Slurm uses one CPU and 1 GiB; this is a small compile/run probe, not a
build job. The pinned compiler and VVP hashes match attempt 08.

## Result

Slurm job 3179 passed the corrected goto-positive assertion under both
`-g2017` and `-g2023` with `-gassertions`. The run used source revision
`6604c23e197980b69a5b6b69864ff8ef8d05eba3`, Icarus SHA-256
`f8c0376ed73753c3327b1d7f5d4d647820836799064d965be7e1a8fbb9403ccd`, and
VVP SHA-256
`53ad297f5370175e0df8af51c5947b7b34c723cf258617febf716cf82168249b`.
The exact staged probe SHA-256 is
`c02d19ff66ca752c024924952c02aa60bf2271140c206d2d24a555cefa3f4886`.
Both logs say `PASSED: goto repetition ends at second b`.
