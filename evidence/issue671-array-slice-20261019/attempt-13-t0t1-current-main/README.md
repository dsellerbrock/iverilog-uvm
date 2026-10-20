# Attempt 13 — current-main #671 T0/T1

Exact source commit: `6d09976cc07c4a18d8a92a836e9979de980dead9`, rebased on current `origin/main` `8c95b5cc1`. Slurm job 3254 completed with `ExitCode=0:0`, 2 CPUs, 3 GiB requested, and 3:56 runtime. The build log's `/usr/bin/time -v` reports 1,671,012 KiB peak RSS for the build step.

T0 passed:

- Build and install succeeded. Installed tool hashes: `iverilog` `bf854cf628958076b476bf7619d41f4d57a9e0411299ef57c054bf035eed1e96`; `vvp` `1a1719dc73304e581fddf69e4e43067f9040bb6c057b63cedf904cabb45741e8`.
- Issue reproducer: legacy 2/2 and JSON 2/2 passed across the 2017/2023 cases.
- Smoke: legacy 56/56, VPI 133/133, negative tests 152/152; all remaining `ci/run-smoke.sh` checks completed with job exit 0.

T1 passed on the graph-selected Chapter 7 focus: legacy 91/91 and JSON 84/84.

Remote results and the scheduler log were copied under `raw-slurm-3254/`; their bytes match `raw-slurm-3254/SHA256SUMS`. Slurm staged source commit `6d09976cc07c4a18d8a92a836e9979de980dead9`; the generated transfer archive was 271,554,215 bytes with SHA-256 `beffc0db9d055d594c0870e80420f5286c74639b157964ff00e0dad44d167c48` and is omitted because GitHub rejects files over 100 MB. `SHA256SUMS` at this attempt's root verifies the retained job script and source commit record.
