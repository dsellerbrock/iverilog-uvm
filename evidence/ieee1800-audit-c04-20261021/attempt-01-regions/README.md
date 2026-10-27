# Clause 4 scheduling-region probe

This initial attempt follows the audit lead's prescribed design. Its source accidentally declared `c` as scalar `logic`; therefore `c <= 2` correctly truncated to 0 and the expected value was wrong. The raw run is retained as a probe-design check, not evidence of an NBA-order gap. The corrected two-bit probe is in [`attempt-02-regions-width-corrected`](../attempt-02-regions-width-corrected/README.md). The standards basis and the §4.6/§4.7 citation check are recorded in [`STANDARD.md`](STANDARD.md).

The original source, inputs, Slurm script, and job 3702 output are preserved under [`input/`](input/) and [`raw-slurm-3702/`](raw-slurm-3702/); see [`RESULT.md`](RESULT.md) for its limited interpretation.
