# §8.27 parameterized forward class typedef (Slurm probe)

The test follows the positional and named parameter overrides from IEEE 1800-2017/2023 §8.27. An added `T` property makes the type override observable by assigning real values; a default-specialization control confirms `T=int` is used. No `$bits(real)` expectation is used.

Expected stdout under `-g2017` and `-g2023`: `FP 1 2 2 1.50 2.25 2`.

Host/toolchain: DAN-DESKTOP, pinned Icarus `/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin/{iverilog,vvp}`. Resources: 1 CPU, 1 GiB, 10 minutes; each compile/run times out after 30 seconds. Root: `-s top`.

## Archive integrity

- `results-3508.tar.gz`: 2915 bytes; SHA-256 `b7ccbf6d0282c1399d385961e27b94484a3407ea0b15fca3b4e5913960ea1640`.
