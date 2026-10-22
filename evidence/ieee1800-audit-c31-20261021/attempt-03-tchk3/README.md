# Clause 31 final timing-check tranche

This paired-edition probe covers `$recrem`, the default timer-based `$timeskew` and `$fullskew` paths in both event orders, `edge [01]`, conditioned timing-check events, vector timing signals, and negative `$setuphold` limits with explicit delayed signals. The positive cases share a notifier and schedule reports at distinct times. See [`STANDARD.md`](STANDARD.md) for the rule-derived windows and [`DEDUPE.md`](DEDUPE.md) for the open/closed search.

The negative-limit probe follows IEEE §31.9.1's functional-model requirement and does not assume a particular delay value for `dclk` or `dd`. The option check includes Icarus compiler/runtime help and its manual; the negative probe is also compiled without any extra option in both editions. The compiler's actual response to the negative limit determines the result.

Toolchain: `/home/dsell/toolchains/iverilog-fb584a25-20261020`, source commit `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`. Each compile and simulation has a 30-second timeout. Slurm requests 1 CPU, 1 GiB and 10 minutes.

Sources: [`p31_tchk3.sv`](../../../tests/1800_audit/c31/p31_tchk3.sv) and [`p31_neg.sv`](../../../tests/1800_audit/c31/p31_neg.sv).
