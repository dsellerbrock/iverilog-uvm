# Clause 16.14, 16.15, and 16.17 probes

Slurm job 3219 ran the five probes below under both `-g2017` and `-g2023`,
with `-gassertions`. All ten compilations and simulations returned zero.

The run used Icarus main `c31cbf1b52f1a39d5775f276e2340525a444a79e` from the
protected toolchain
`/home/dsell/toolchains/iverilog-a3-audit-c16-9-4-c31cbf1b-f958f855-b0e2b7f2`.
The Slurm request was one CPU, 1 GiB, and 20 minutes; each compile and run had
an independent 120-second timeout.

## Results

- §16.14: procedural `assert`, `assume`, and `cover property` pass; module-item
  and procedural `restrict property` forms compile and simulate without
  affecting the test's result.
- §16.15: the assertion before a later `default disable iff` fires during reset
  (`late-default=1`), although §16.15 requires it to be disabled
  (`late-default=0`). Controls match the standard: declaration before the
  assertion disables it, explicit assertion-level disable overrides the
  default, explicit `disable iff (1'b0)` does not inherit it, property-level
  disable works, and a child module does not inherit the parent default.
  The observed and standard lines were identical between editions:

  ```text
  OBSERVED: late-default=1 early-default=0 explicit=1 zero=1 property=0 child=1
  STANDARD: late-default=0 early-default=0 explicit=1 zero=1 property=0 child=1
  ```

- §16.17: one passing and one failing `expect` each execute the matching action;
  the self-check passes.

## Probe files

- `tests/1800_audit/c16/p16_14_procedural_assertions.sv`
- `tests/1800_audit/c16/p16_14_restrict_module.sv`
- `tests/1800_audit/c16/p16_14_restrict_procedural.sv`
- `tests/1800_audit/c16/p16_15_disable_resolution.sv`
- `tests/1800_audit/c16/p16_17_expect.sv`

## Reproduction and hashes

The exact batch script is `run.sbatch`. Its input archive and the complete
Slurm result archive are retained as `input-r2/probes.tar.gz` and
`results-3219.tar.gz`.

```text
results-3219.tar.gz  db2eaa5bf53ccd99d686cf98f11f627f933630a975b5cec19c2c1cd9ef78cb36
input-r2/probes.tar.gz  4d48698d6c629da94b777cfe20b72ad16af9f1f6d349456b5c022c5febfa17
run.sbatch  d0ebd566e42d5b3a7515d881bc81306e3daf2ffff30ec06dd77c520e7e4dc1c9
```

## Archive integrity

- `input-r2/probes.tar.gz`: 1698 bytes; SHA-256 `4d48698d6c629da94b777cfe20b72ad16af9f1f6d349456b5b5c022c5febfa17`.
- `input/probes.tar.gz`: 1581 bytes; SHA-256 `d423d00c5aadba6ecd3d19e29712a4b20038cba0c27b6b182a24423d5044cd4d`.
- `results-3219/input/probes.tar.gz`: 1698 bytes; SHA-256 `4d48698d6c629da94b777cfe20b72ad16af9f1f6d349456b5b5c022c5febfa17`.
