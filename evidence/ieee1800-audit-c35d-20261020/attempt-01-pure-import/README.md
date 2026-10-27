# §35.5.1.3 / §35.5.2 pure imported function probe

This runs the existing basic DPI regression under both editions. Its imported
functions are declared `pure` and calculate results solely from their input
arguments; the C functions have no side effects.

- SystemVerilog: [`dpi_basic_test.sv`](../../../tests/dpi_basic_test.sv)
- C companion: [`dpi_basic_test.c`](../../../tests/dpi_basic_test.c)
- Standard basis: [`STANDARD.md`](STANDARD.md)
- Expected stdout: `DPI BASIC TEST: PASS (6/6)`
- Compiler: pinned main toolchain `cc25756d1` at
  `/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb`
- Slurm resources: 1 CPU, 1 GiB; 30-second timeout for each compile, link,
  and simulation command
- Harness: [`run.sbatch`](run.sbatch)

This adds paired-edition evidence only; the existing test and golden are not
modified.
