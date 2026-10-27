# Clause 31 skew timer probe

This paired-edition probe distinguishes the default timer-based `$timeskew`/`$fullskew` behavior from event-based behavior, using the no-data, very-late-data, and explicit event-based cases selected by the audit lead. `$skew` with no data event is the control. Each notifier transition prints its case and time; the final line reports case totals. The first combined attempt was rejected because Icarus reports the explicit `event_based_flag` as unsupported; its logs and source are preserved in [`raw-slurm-3690`](raw-slurm-3690/). The second attempt confirms default timer reporting is missing for `$timeskew` and `$fullskew`; the separate event-flag compile is still rejected.

The quoted standard definitions and expected observations are in [`STANDARD.md`](STANDARD.md). The prior open/closed searches for `$timeskew` and `$fullskew` are reused and refreshed in [`DEDUPE.md`](DEDUPE.md); #890 only mentions those checks as positive controls, not as gaps.

The source is [`p31_skewtimer.sv`](../../../tests/1800_audit/c31/p31_skewtimer.sv). Toolchain: `/home/dsell/toolchains/iverilog-fb584a25-20261020`, Icarus source commit `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`. Slurm requests 1 CPU, 1 GiB, 10 minutes. Each compile and simulation has a 30-second timeout.
