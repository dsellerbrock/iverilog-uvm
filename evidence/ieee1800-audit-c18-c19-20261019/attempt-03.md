# §18.12 null-argument probe

- Slurm job 2899 on DAN-DESKTOP, 1 CPU / 1 GiB, exit `0:0`, elapsed 1 second.
- Base commit: `82023726be90ab269d6e0ef5e755ebb69e6f648c`; Icarus 13.0 devel SHA-256 `234d4e6ee4a27f636b1b07de19e31db0ea510601945ed5aaf2885edb8e1d4f42`.
- With the correct top module, `std::randomize(null)` compiled and ran with exit 0 in both `-g2017` and `-g2023`, confirming the gap tracked by [#621](https://github.com/dsellerbrock/iverilog-uvm/issues/621).
- An initial job 2898 used `-s test` although the probe declares `module top`; it only reported the missing top. Job 2899 corrected that harness argument. Both raw attempts are retained in `audit-c18-null-attempt-03.tar.gz`.
