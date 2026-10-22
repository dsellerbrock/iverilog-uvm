# Clause 7.2–7.3 structure and union probes

Slurm job 3221 ran on DAN-DESKTOP using the pinned Icarus 13.0 development
toolchain built from main `c31cbf1b52f1a39d5775f276e2340525a444a79e`.
The compiler SHA-256 is
`f958f85546420cdaf3c67d73e7c377e63a55a3df9c4dca6de16955e81000b818`; the VVP
SHA-256 is
`b0e2b7f230be80efe2e04b28ad5a688c46f93eaad692d34bfe27895a61983be6`.
The job requested one CPU, 1 GiB, and 10 minutes; every compile and simulation
had a 120-second timeout. The result script reported `OVERALL_RC=0`.

## Results

- IEEE 1800-2017 and 1800-2023: packed structure member access, most-significant
  member layout, vector slices, whole-structure copy, signed packed vector
  behavior, unpacked members, and whole-unpacked-structure copy passed.
- Both editions: packed untagged-union overlay and vector selection passed;
  assignment and whole-copy of the active unpacked-union member passed.
- Both editions: tagged-union constructors and access to each selected member
  passed, including a `void` tag.
- IEEE 1800-2023: a soft packed union retained the upper bits after writing a
  narrower member, as required by §7.3.1. The same syntax was rejected under
  `-g2017` with the edition diagnostic: `soft packed unions requires
  IEEE1800-2023; compile with -g2023 (or -glatest)`.

These checks cover the listed constructs only; they do not establish complete
Clause 7 conformance.

## Probe files

- `tests/1800_audit/c07/p07_02_structures.sv`
- `tests/1800_audit/c07/p07_03_untagged_unions.sv`
- `tests/1800_audit/c07/p07_03_02_tagged_unions.sv`
- `tests/1800_audit/c07/p07_03_1_soft_packed_union_2023.sv`

## Reproduction and hashes

The exact Slurm script, staged test archive, submission metadata, and complete
job output/results are retained in this directory:

```text
results-3221.tar.gz  d4012d4a1993db92d511cc1021f30c1a3c651534df474b21face6a93ca4836c9
input/probes.tar.gz  bd320d959e1d4aef69b0e24c2a4d158d80d71f31503cdb1a57d6e54fb8c3b9fe
run.sbatch  61ba327c1604541f6991c90699f6c96d92eb396d85feb0ebd2114892b31cb451
```

The copied result archive SHA-256 matched the remote archive. The job no longer
appeared in `squeue`; Slurm accounting is disabled on this host, so no separate
accounting exit-state or elapsed-time record was available. After preserving
and verifying the evidence, the isolated 45,206-byte remote run directory was
removed.
