# IEEE 1800 §7.10.4 queue assignment probe

## Result

The standard's tested append, prepend, front/back removal, before/after
insertion, empty-assignment, and trimming examples all produced the expected
queue contents under both language editions. Every compile and run returned
0; stdout was exactly `PASS\n`; compiler and runtime stderr were empty.

This is evidence for the listed examples only. Lead classification is pending;
no new gap issue is proposed from this passing probe.

## Environment and commands

- Slurm job 3560 on DAN-DESKTOP; 1 CPU, 1 GiB, 30-second timeout on each
  compile and run command.
- Compiler: Icarus Verilog 13.0-devel `cc25756d1`.
- `iverilog` SHA-256: `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`.
- `vvp` SHA-256: `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`.
- Probe source SHA-256: `459b7ac5e9a58d1ee9f66bff4447748584a74f282af8f19dda17c353c8a66b9a`.
- Staged commit: `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`, branch
  `m7-1800-audit-c08`, with the probe source untracked at run time.
- Slurm start and end timestamps both read `2026-10-20T20:22:02Z` (second
  resolution). `squeue -j 3560` was empty after `sbatch --wait` returned 0.
  Slurm accounting is disabled, so exact scheduler elapsed time is unavailable.

For each edition 2017 and 2023, the script ran:

```sh
timeout --kill-after=2s 30s "$IVL" -g"$edition" -s p07_10_4_assignment \
  -o "$image" "$SRC"
timeout --kill-after=2s 30s "$VVP" "$image"
```

The complete script, per-edition logs, stdout, stderr, tool versions, hashes,
timestamps, and scheduler output are preserved in `run.sbatch` and
`remote-3560/`.

## Raw per-edition results

```text
edition  compile_rc  run_rc  stdout_match
2017     0           0       YES
2023     0           0       YES
```
