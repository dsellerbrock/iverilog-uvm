# Initial combined array-query attempt (partial)

- Slurm job: `3522` (`1` CPU, `1G`, five-minute limit; completed)
- Simulator source commit: `cc25756d187314742d347267c2a513b3e640a7fb`
- Toolchain: Icarus 13.0-devel (`cc25756d1`); hashes are in [`slurm-3522.out`](slurm-3522.out).

Under both `-g2017` and `-g2023`, `p07_11_query.sv` failed to compile at the combined constant declaration `localparam int SW = $size(Word), SR = $size(Ram,2);`: Icarus reported that reference to variable `Ram` is not allowed in a constant expression. This conflicts with the fixed-size array constant-expression example in §20.7; a follow-up isolates the `Word` and `Ram` expressions separately.

Both proposed compile-negative tests compiled successfully with empty stderr under both editions. This first attempt did not run those binaries; runtime behavior is recorded in the isolated follow-up.

Raw compiler output and errors are in [`results/`](results/). The original submitted sources and hashes are recorded in the batch log. This partial attempt is preserved so it is not confused with the corrected follow-up.
