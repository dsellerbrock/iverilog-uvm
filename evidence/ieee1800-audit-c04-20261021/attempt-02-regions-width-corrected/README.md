# Clause 4 region-order probe, corrected width

This paired-edition run corrects the initial probe's scalar `c` to a two-bit value, so the assigned value 2 is representable. It checks Active, Inactive, NBA, Reactive, Postponed, same-process NBA source order, and old-value capture by `d`.

The source is [`p04_regions.sv`](../../../tests/1800_audit/c04/p04_regions.sv); input copies and the Slurm script are in [`input/`](input/). See [`STANDARD.md`](../attempt-01-regions/STANDARD.md) for both-edition clause references, [`DEDUPE.md`](../DEDUPE.md) for open/closed issue searches, and [`RESULT.md`](RESULT.md) for job 3704 output. The run used protected Icarus source commit `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`, 1 CPU, 1 GiB, and 30-second per-command timeouts.
