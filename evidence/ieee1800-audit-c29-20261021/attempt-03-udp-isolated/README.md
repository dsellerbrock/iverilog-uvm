# IEEE 1800 Clause 29 isolated UDP probes

This follow-up isolates each §29.8–§29.10 behavior after the combined attempt was stopped by Icarus's UDP instance-array rejection. Standards requirements and citations are recorded in [`../attempt-02-udp-more/input/STANDARD.md`](../attempt-02-udp-more/input/STANDARD.md); open+closed dedupe is recorded in [`../attempt-02-udp-more/DEDUPE.md`](../attempt-02-udp-more/DEDUPE.md).

## Probes

- [`input/p29_more.sv`](input/p29_more.sv): optional instance name, two delays, and mixed level/edge rows; the dominance observation was strengthened with an edge-only control in attempt 04.
- [`input/p29_instance_array.sv`](input/p29_instance_array.sv): scalar UDP output instances mapped to a two-bit instance-array port.
- [`input/n29_delay3.sv`](input/n29_delay3.sv): three delay values; expected to be rejected under §29.8.
- Expected positive output files and `run.sbatch` are alongside this README.

The run used protected Icarus 13.0-devel toolchain source commit `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`, 1 CPU, 1 GiB, and 30-second per-command timeouts. Job 3693 completed successfully in under one second. Results and raw logs are in [`RESULT.md`](RESULT.md) and [`raw-slurm-3693/`](raw-slurm-3693/).
