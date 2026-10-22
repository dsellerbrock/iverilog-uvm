# Clause 38 second VPI probe

This paired-edition probe exercises `vpi_get_str`, `vpi_get`, `vpi_handle_by_index`, timed `vpi_put_value` with `vpiInertialDelay`, `cbAtStartOfSimTime` plus `vpi_get_time`, `vpi_remove_cb`, and `vpi_control(vpiFinish, 0)`. The exact normative rules under test are cited in [`STANDARD.md`](STANDARD.md); open+closed issue search is in [`DEDUPE.md`](DEDUPE.md).

Expected output and runtime sequence are recorded in [`RESULT.md`](RESULT.md) after the Slurm job. The VPI callback structures and delayed write data use static storage to avoid lifetime assumptions.
