# Plain queue-of-struct `find()` control

- Probe: [`p07_12_4_iterarg_control.sv`](../../../../tests/1800_audit/c07/p07_12_4_iterarg_control.sv)
- Simulator source commit: `cc25756d187314742d347267c2a513b3e640a7fb`
- Slurm job: `3520` (`1` CPU, `1G` memory; completed)
- Toolchain: Icarus Verilog 13.0-devel (`cc25756d1`); `iverilog` SHA-256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`, `vvp` SHA-256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`
- Command for both editions: `iverilog -g{2017,2023} -s p07_12_4_iterarg_control -o p07_12_4_iterarg_control-{2017,2023}.vvp p07_12_4_iterarg_control.sv`, then `vvp p07_12_4_iterarg_control-{2017,2023}.vvp` (30-second per-command timeout)
- Result: compile and run exit code `0` under both editions; stderr was empty. Both printed `C1 2 20`.

This control verifies that Icarus supports `find()` on this queue-of-struct shape. The 2023 failure in [`attempt-01-map/`](../attempt-01-map/) is specific to the optional iterator-index argument.

Raw output is in [`results/`](results/) and the batch output is [`slurm-3520.out`](slurm-3520.out).
