# IEEE 1800 §§24.4 and 24.7 paired probe results

## Environment

- Completed Slurm job 3658 on DAN-DESKTOP, run directory `/home/dsell/slurm-runs/iverilog-uvm/a3/a3-m7-c24-20261021-3657`, partition `verilog`; requested 1 CPU, 1 GiB, 5 minutes. At submission, 18 of 20 CPUs were allocated. `squeue -j 3658` was empty after completion; Slurm accounting storage is disabled, so elapsed time and peak RSS are unavailable.
- Protected toolchain: Icarus 13.0-devel, source `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`, invoked with `-B /home/dsell/toolchains/iverilog-fb584a25-20261020/lib/ivl`.
- All six compile/run pairs completed without timeout in job 3658. Source and executable SHA-256 values are in [`remote-3658/logs/a3-c24-race-3658.out`](remote-3658/logs/a3-c24-race-3658.out).

## Results

| Probe | `-g2017` | `-g2023` | Observation |
| --- | --- | --- | --- |
| Program testbench on design `dut` | Compile/run 0; `T 5 q=0`, `T 15 q=1`, `T 25 q=2` | Same | Program samples `q` after the design NBA update, then changes `d` after the design sampled the prior value. This matches the §24.4 race-avoidance behavior. Program completion ends the simulation implicitly. |
| Module control with identical `dut` and test sequence | Compile/run 0; `T 5 q=x`, `T 15 q=0`, `T 25 q=1` | Same | The module testbench reads `q` before the NBA at each edge; the first read is `x` and the output lags, exposing the Active-region race. It finishes explicitly at time 26. |
| `$exit` from module initial, followed by `AFTER`; a second module initial prints `LATE` at time 10 | Compile/run 0; empty stdout/stderr | Same | The call ends the simulation and suppresses both outputs, but §24.7 requires a call not originating in a program initial procedure to be ignored. This confirms the module-origin gap already tracked by #786. |

The first harness attempt, Slurm job 3656, preserved the same program and module outputs but timed out the module-only control after its three samples because that control had no finish statement. Those diagnostic logs are in [`remote-3656-incomplete/`](remote-3656-incomplete/); they are not the completed run. The rerun adds an explicit finish and completes all cases.

## Standard basis

IEEE 1800-2017/2023 §24.4 says the program construct schedules execution in the Reactive region after design events have been processed, including clocks driven by nonblocking assignments. Section 24.3.2 specifies that sequential code in programs and the corresponding program-port updates occur in the Reactive region set. IEEE 1800-2017 §24.7 says `$exit` from a thread that does not originate in a program initial procedure “shall be ignored”; 1800-2023 uses the same rule. Thus the program output is race-free, while the module-origin `$exit` result violates §24.7.

Issue #786 was retitled to the §24.7 module-origin behavior and updated with [the paired reproduction](https://github.com/dsellerbrock/iverilog-uvm/issues/786#issuecomment-6309671512). Its earlier program-origin expectation correction remains in [comment 6309531937](https://github.com/dsellerbrock/iverilog-uvm/issues/786#issuecomment-6309531937).

After copying the raw logs locally, only this job's remote `build/` directory was removed; its `input/` and `logs/` remain.
