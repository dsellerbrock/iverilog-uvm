# #419 DD-047 nested packed-struct array sizing probe

- Host: DAN-DESKTOP, Linux x86_64 under WSL2.
- Candidate source: commit `f9c2cb5742b23e82aa13b5c4ab26802bb10cefd8`; `git archive HEAD` SHA-256 `565de12d8486ba2b4eb403cae08a161676750c85e7390ba6632d37e7de0bc69a`.
- Probe source: [`dd047_nested_resize.sv`](../dd047_nested_resize.sv), SHA-256 `72f7530abaa43ee4954a9350f10844e13048936df1fe8c70b919ed5d20781475`.
- Slurm job 2809: COMPLETED, `ExitCode=0:0`, 2 CPUs, 4 GiB requested, 00:03:03 elapsed. Slurm accounting is disabled, so MaxRSS is unavailable.
- Candidate `iverilog` SHA-256 `679fabf2a9aeaabed09e287035584c82b1446186fadbad4df70e4db031546405`; `vvp` SHA-256 `619b1f750bb3462a8ec2a8728f8264e493412706884ae501c03dba2fdd1fca1b`.
- With `-g2017` and `-g2023`, compile and run both exited 0 and printed `PASS`.
- The same probe also passes on the current-main toolchain at `c344d20197a569dea8936bad95de3d185b1e78dc`: `iverilog` SHA-256 `a45e1243e270533064cccad20b5ad1f6474795360a6e614965de2d84017d69b8`; `vvp` SHA-256 `8dd2a6a19e5aa938ed6a8961542a003c90b9d5bbfc85952222737d57ec7dd657`. Both strict editions compile and run to `PASS`.

The test covers a direct `rand packed_struct[][]` class property, constrained outer and row sizes, and constrained elements. It confirms this bounded DD-047 shape is already supported; it does not qualify the full ADC interaction cited by DD-047.

Raw commands and logs are in this directory. `probe.log` contains configure/build/install and the candidate probe; the individual `compile-*` and `run-*` logs preserve the focused outputs.
