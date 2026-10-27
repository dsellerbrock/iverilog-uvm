Baseline regression result

- Slurm job: 3840 on DAN-DESKTOP, 1 CPU / 1 GiB, per-command timeout 30 s.
- Compiler: pinned audit toolchain `cc25756d1` at `/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/bin`.
- Both `-g2017` and `-g2023` compile the positive case but simulation fails because the default resolves the earlier formal (`b` is 2 instead of 101).
- Both editions also accept the negative case even though `a` is absent from the module declaration scope.
- `run.sbatch` and the raw job log are retained; the two source files are the paired regression fixtures in `ivtest/ivltests/`.
