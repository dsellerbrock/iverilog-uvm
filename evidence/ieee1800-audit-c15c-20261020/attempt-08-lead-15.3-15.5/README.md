# Lead-directed §15 probe rerun

- Slurm job: 3384 (`a3-c15-lead`), submitted 2026-10-20 MDT.
- Source baseline: `cc25756d187314742d347267c2a513b3e640a7fb` (`origin/main` at run time).
- Compiler: Icarus 13.0-devel from the current-main build; isolated copy at `/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/`.
- Compiler SHA-256: `iverilog` `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`; `vvp` `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`.
- Probes: `p15_03a_semaphore.sv`, `p15_05a_events.sv`, `r15_wait_order_fail.sv`, each compiled and run under `-g2017` and `-g2023` where compilation succeeds.
- Timeout: 20 seconds per compiler and simulator process, using the repository process-group timeout wrapper.
- Resources: 1 CPU, 1 GiB, 10-minute wall limit. One sequential lightweight test set; the memory cap exceeds the recorded 437,536 KiB peak of the prior full regression gate.
- Run directory: `/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c15-lead-20261020-1/`.
- Raw results will be copied here after the job completes.

## Outcome

- Slurm job 3384 completed in 1 second with `COMPLETED`, `ExitCode=0:0` (`sacct` accounting unavailable on the host).
- Both editions produced semaphore `RESULT pass=5 fail=0`.
- Both editions rejected the event test at source lines 9 and 23 (event-typed task formal); run was not attempted.
- Both editions emitted the `wait_order` out-of-order error and then printed `SURVIVED`, with simulator exit code 0.
- Classification and dedupe are pending the audit lead. No issue was filed and the matrix was not changed.
