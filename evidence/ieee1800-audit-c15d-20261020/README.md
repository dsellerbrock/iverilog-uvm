# Lead-directed event construct isolation

- Slurm job 3385 (`a3-c15-event-bisect`), using the pinned shared toolchain at `/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/`.
- Source/compiler baseline: Icarus 13.0-devel, `cc25756d187314742d347267c2a513b3e640a7fb`.
- Eight independent probes under `tests/1800_audit/c15/ev/`, each compiled first and run only on compile success, under both `-g2017` and `-g2023`.
- Each compile and run is limited to 20 seconds with the repository process-group timeout wrapper.
- Slurm request: 1 CPU, 1 GiB, 10 minutes. The last full regression peak was 437,536 KiB; the request provides over 1.25x headroom for this sequential, focused test set.
- Remote scratch is isolated at `/home/dsell/slurm-runs/iverilog-uvm/A3/audit-c15-event-bisect-20261020-1/`; results will be copied into this directory, then the run directory will be retired.
- Probes and checksums are preserved under `input/`; exact Slurm script is `run.sbatch`.

## Result

Only `ev_task_formal.sv` failed to compile (rc 2, syntax error at line 1) in both editions. The other seven probes passed with the outputs listed in `RESULT.md`. The lead's open+closed dedupe found no event-typed task formal issue; #439 and #441 cover distinct adjacent behavior. Lead classification and issue filing are pending.
