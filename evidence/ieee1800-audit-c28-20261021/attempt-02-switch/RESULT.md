# Clause 28 switch-level probe — initial result

## Environment

- Slurm job 3661 on DAN-DESKTOP; 1 CPU, 1 GiB, 10-minute limit; completed in 1 second with exit code 1.
- Protected toolchain: Icarus 13.0-devel, source `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`; executable and library SHA-256 values are in [`remote-3661/a3-c28-switch-3661.out`](remote-3661/a3-c28-switch-3661.out).
- Probe sources and their hashes are in [`input/`](input/); exact compiler/run logs are in [`remote-3661/logs/`](remote-3661/logs/).

## Results

| Source | `-g2017` | `-g2023` |
| --- | --- | --- |
| `p28_switch.sv` | Compile exit 1: `p28_switch.sv:3: sorry: trireg nets not supported.` | Same diagnostic and exit |
| `p28_trireg_decay.sv` | Compile exit 1: `p28_trireg_decay.sv:2: sorry: trireg nets not supported.` | Same diagnostic and exit |

The direct compiler rejection establishes that `trireg` is unsupported, so this attempt cannot assess the MOS, resistive-strength, or `tran` outputs in `p28_switch.sv`: compilation stops at its `trireg` declaration. Those independent switch checks need a source without `trireg`. The dedicated decay source confirms that the decay feature cannot currently be compiled either. Open+closed searches for `nmos`, `tran`, `rnmos`, `trireg`, `charge decay`, and `28.13` returned no matches; see [`DEDUPE.md`](DEDUPE.md).

No scheduler accounting is configured, but `scontrol show job 3661` reported `JobState=FAILED`, `ExitCode=1:0`, and `RunTime=00:00:01`. This is a simulator compile result, not an infrastructure loss. The remote build directory was removed after copying the logs; remote inputs and logs were kept.
