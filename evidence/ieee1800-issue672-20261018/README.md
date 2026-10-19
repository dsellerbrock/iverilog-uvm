# Issue #672 T0/T1 evidence

Base: `c344d20197a569dea8936bad95de3d185b1e78dc`

Host: DAN-DESKTOP (Slurm partition `verilog`)

T0 job: 2825, 3 CPUs, 3 GiB

T1 rerun: 2826, 3 CPUs, 3 GiB

Installed tools from job 2825:

- `iverilog`: `4e3bbf2d8fbc8a8be03fee8271dbb2d160d2316e6386c7b2f9ec65fc92aa9f30`
- `vvp`: `974abe410fff6c18e1f3155bf12b80ba1bab02d37ee9ef345f7328c866cbdf6a`

## Results

- Issue reproducer: `iverilog -g2017` and `iverilog -g2023`, followed by `vvp`; both printed `PASSED` (job 2825).
- T0 smoke set: `ci/run-smoke.sh`; 133 passed, 0 failed, 0 not implemented (job 2825, exit 0).
- T1 specialization focus: `.github/ivtest_focus_gate.sh regress-vif-parameter-specialization-focus-legacy.list regress-vif-parameter-specialization-focus-vvp.list`; 70/70 legacy and 70/70 JSON tests passed (job 2826, exit 0). Both new #672 cases pass in both runners.
- `make -j3`: exit 0, wall 2:06.29. `make install`: exit 0, wall 0:00.40. Each direct compile and run: exit 0, less than 0.01 s reported.
- T0 smoke: exit 0, wall 0:39.27. T1 focus: exit 0, wall 0:01.97.
- Peak RSS for `make -j3`: 1,662,548 KiB. T0 smoke peak: 109,308 KiB. T1 peak: 16,540 KiB.

Direct reproducer commands used the paired sources:

```sh
iverilog -g2017 -s sv_param_config_nested_path -o repro-2017.vvp ivtest/ivltests/sv_param_config_nested_path_2017.v
vvp repro-2017.vvp
iverilog -g2023 -s sv_param_config_nested_path -o repro-2023.vvp ivtest/ivltests/sv_param_config_nested_path_2023.v
vvp repro-2023.vvp
```

Job 2825's initial T1 invocation used `ivtest/` prefixes although the gate expects manifest names relative to `ivtest/`; it stopped before running tests (exit 2). Job 2826 reran T1 with the correct arguments against the completed build. This was a harness invocation error, not a test failure.

The two focused JSON cases were run by T1. The `ivtest/regress-vvp.list` registration was added to the local patch after the job 2825 source snapshot, so the full default JSON list remains for the eventual T2 batch gate.

Raw logs and result files are in this directory. The remote copies remain under `/home/dsell/slurm-runs/iverilog-uvm/A3/issue672-t0-20261018-02/` until cleanup after commit. No T2/full gate has run because this PR is not yet in a batch.
