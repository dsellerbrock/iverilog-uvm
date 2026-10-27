# Queue-element reference persistence result

- Probe: [`p07_10_3_ref.sv`](../../../../tests/1800_audit/c07/p07_10_3_ref.sv)
- Simulator source commit: `cc25756d187314742d347267c2a513b3e640a7fb`
- Slurm job: `3518` (`1` CPU, `1G` memory; completed)
- Toolchain: Icarus Verilog 13.0-devel (`cc25756d1`); `iverilog` SHA-256 `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`, `vvp` SHA-256 `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`
- Command for each edition: `iverilog -g{2017,2023} -s p07_10_3_ref -o p07_10_3_ref-{2017,2023}.vvp p07_10_3_ref.sv`, then `vvp p07_10_3_ref-{2017,2023}.vvp` (30-second per-command timeout)
- Result: compile and run exit code `0` in both editions; stderr was empty.

Both editions printed the expected values for all five cases:

```text
R1 1 2 99 8
R2 99 8
R3 7 2 99 8
R4 2 8
R5 2 4 8 6
```

R1/R2/R3 confirm the reference continues to identify the same surviving element across `push_front`, removal of a different element, and `insert`. R4/R5 confirm writes through references to a deleted element or to elements made outdated by whole-queue assignment do not change the queue.

IEEE 1800-2017 and 1800-2023 §7.10.3 specify that references to existing elements not deleted by a queue method do not become outdated, while assignment to the queue makes references to its original elements outdated. IEEE 1800-2017 §13.5.2 p. 331 and 1800-2023 §13.5.2 p. 349 specify that writes to removed array elements made by a called subroutine are not visible outside the subroutine.

Raw compile/run output and stderr files are in [`results/`](results/); the original batch output is [`slurm-3518.out`](slurm-3518.out). Open/closed issue searches and review of the only open search hit are recorded in [`DEDUPE.md`](DEDUPE.md).
