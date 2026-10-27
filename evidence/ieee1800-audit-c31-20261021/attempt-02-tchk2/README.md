# Clause 31 timing-check tranche 2

This paired-edition probe adds `$recovery`, `$removal`, `$period`, `$skew`, `$setuphold` (one setup and one hold violation), and `$nochange` to the existing Clause 31 audit. Each check gets a distinct signal group and a distinct event time. All checks share one notifier, whose transitions are counted. Only `-gspecify` runs measure the IEEE timing behavior.

Source: [`p31_tchk2.sv`](../../../../tests/1800_audit/c31/p31_tchk2.sv). Exact 2017/2023 clauses, window rules, expected times, and pages are in [`STANDARD.md`](STANDARD.md). Both editions use the pinned Icarus toolchain at `/home/dsell/toolchains/iverilog-fb584a25-20261020` (source commit `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`). The Slurm run requests 1 CPU, 1 GiB, and 10 minutes; every compile and simulation has a 30-second timeout.
