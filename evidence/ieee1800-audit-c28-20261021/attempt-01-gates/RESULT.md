# IEEE 1800 Clause 28 gate and strength probe results

## Environment

- Slurm job 3660 on DAN-DESKTOP, completed with `JobState=COMPLETED`, `ExitCode=0:0`, `RunTime=00:00:01`; 1 CPU and 1 GiB requested.
- Protected Icarus 13.0-devel toolchain source `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`; executable and library SHA-256 values are in [`remote-3660/slurm-3660.out`](remote-3660/slurm-3660.out).
- Probe source hash is in the same raw output. Edition-specific compiler and runtime logs are under [`remote-3660/logs/`](remote-3660/logs/).

## Results

Both editions compiled and ran successfully with identical output:

| Edition | Compile | Run | Output |
| --- | --- | --- | --- |
| `-g2017` | 0 | 0 | `G x 0 StH 0 1 x Pu1`; `D1 12 0`; `D2 14 1`; `D3 25 1`; `D4 27 0` |
| `-g2023` | 0 | 0 | Same |

The result matches the standard-derived expectation in [`README.md`](README.md): logic-gate X propagation, `bufif1` H strength, wired-net resolution, strong/pull strength formatting, and distinct rise/fall timing all matched. The open+closed dedupe searches found no Clause 28 gate, switch, strength, or delay issue; see [`DEDUPE.md`](DEDUPE.md). The lead classified this tested subset as IMPLEMENTED and requested additional switch and `trireg` coverage before updating the parent Clause 28 status.

The copied raw Slurm log, inputs, script, and evidence are local. After recording them, only this run's remote build directory was removed; remote input and logs were preserved.
