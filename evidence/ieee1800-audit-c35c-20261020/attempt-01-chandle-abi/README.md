# §35.5.5–§35.5.6 chandle DPI ABI probe

This runs the existing `m10j_dpi_chandle_abi_test` under both language
editions. It imports a `chandle`-returning allocator and passes the pointer
back to C for reading and freeing; the same test also checks its existing
real and string ABI controls.

- SystemVerilog: [`m10j_dpi_chandle_abi_test.sv`](../../../tests/m10j_dpi_chandle_abi_test.sv)
- C companion: [`m10j_dpi_chandle_abi_test.c`](../../../tests/m10j_dpi_chandle_abi_test.c)
- Standard basis: [`STANDARD.md`](STANDARD.md)
- Expected stdout: `PASS m10j_dpi_chandle_abi_test`
- Compiler: pinned main toolchain `cc25756d1` at
  `/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb`
- Slurm resources: 1 CPU, 1 GiB; 30-second timeout for each compile, link,
  and simulation command
- Harness: [`run.sbatch`](run.sbatch)

The test source already exists as a project regression. This audit run only
adds paired-edition evidence; it does not edit the regression or its golden.

Results are in [`RESULT.md`](RESULT.md); exact raw logs and hashes are in
[`remote-3563/`](remote-3563/).
