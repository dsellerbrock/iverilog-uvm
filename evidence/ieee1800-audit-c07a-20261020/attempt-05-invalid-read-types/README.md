# §7.10 invalid queue-read probe

This isolates the invalid-read behavior left open in the broad queue probe
(Slurm job 3510), with correct 2-state/4-state controls. It checks an
out-of-range read from nonempty `logic` and `int` queues, a read from an empty
`logic` queue, and a `bit` queue. The source asserts every expected value and
prints `PASS` only when all checks hold.

- Probe: [`p07_10_invalid_read.sv`](../../../tests/1800_audit/c07/p07_10_invalid_read.sv)
- Expected stdout: `OOB_LOGIC 1`, `EMPTY_LOGIC 1`, `OOB_INT 0`, `OOB_BIT 0`, `PASS`
- Standard basis: [`STANDARD.md`](STANDARD.md)
- Compiler: pinned main toolchain `cc25756d1` at
  `/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb`
- Slurm: 1 CPU, 1 GiB; compile and run timeout 30 seconds per edition
- Harness: [`run.sbatch`](run.sbatch)

Paired-edition results are in [`RESULT.md`](RESULT.md); raw files and hashes
are in [`remote-3562/`](remote-3562/).
