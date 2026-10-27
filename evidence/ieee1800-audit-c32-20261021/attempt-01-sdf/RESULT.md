# Clause 32 SDF probe results

## Initial run: job 3666 (invalid input; not a conformance result)

- Host: DAN-DESKTOP, Slurm partition `verilog`; `ExitCode=0:0`, elapsed 1 second; 1 CPU and 1 GiB requested.
- Toolchain: Icarus 13.0-devel, source SHA `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`; binary hashes are in [`slurm-3666-logs/a3-c32-sdf-3666.out`](slurm-3666-logs/a3-c32-sdf-3666.out).
- Probe hashes: `p32_sdf.sv` `e311f556c605d4850607070fc39e9d675255d003a443a760948c7b725a7a8931`; malformed `p32.sdf` `20de21e06fa94c7b3d2c535f0ee8fa6c8c1d6d7a2be14f01326b6a10c9eda40b` (preserved as [`p32-malformed-attempt-01.sdf`](p32-malformed-attempt-01.sdf)).
- The initial IOPATH SDF had 12 opening and 11 closing parentheses: the outer `DELAYFILE` was not closed.
- Both `-gspecify` runtime outputs emitted `SDF ERROR: p32.sdf: Too many errors: syntax error` before displaying the expected sample values. Because the parser reported an error, those values are not valid evidence that annotation worked.
- The 2023 default-mode compile emitted `p32_sdf.sv:8: warning: Omitting $sdf_annotate() since specify blocks and interconnects are being omitted.` The mode-only run output `R1 1`, `R2 1`, `F1 0`, `F2 0`.
- Raw stdout/stderr and scheduler output are preserved in [`slurm-3666-logs`](slurm-3666-logs/).

Root cause is the malformed SDF input, not a simulator conformance conclusion. A balanced corrected IOPATH input and the requested PATHPULSE probe are being rerun in fresh isolated Slurm directory `/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c32-20261021-02`; results will be appended here.
