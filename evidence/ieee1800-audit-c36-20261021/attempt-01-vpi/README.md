# IEEE 1800 Clauses 36–38 VPI probe

The probe registers two system tasks, retrieves simulator information, looks up `p36.r` by name, reads and immediately writes its value with `vpiNoDelay`, iterates the module's nets, and counts three later `cbValueChange` events. It runs under `-g2017` and `-g2023` using one VPI module built by the pinned toolchain's `iverilog-vpi`.

## Standard basis

The relevant IEEE 1800-2017/2023 requirements are quoted in [`STANDARD.md`](STANDARD.md): §38.15 `vpi_get_value`; §38.17 `vpi_get_vlog_info`; §38.21 `vpi_handle_by_name`; §38.23 `vpi_iterate`; §38.34 `vpi_put_value` and `vpiNoDelay`; §38.36/§38.36.1 `vpi_register_cb` and `cbValueChange`; §38.37 `vpi_register_systf` and `s_vpi_systf_data`; and §38.40 `vpi_scan`.

The callback signature follows `vpi_user.h`; the callback data, time, and value structures have static storage so the probe does not depend on whether the simulator copies them at registration. The optional V5 callback-value check was omitted; this probe checks the three callback deliveries only.

Open+closed issue dedupe is in [`DEDUPE.md`](DEDUPE.md); paired-edition commands, compiler/module build provenance, outputs and any harness failures will be recorded in [`RESULT.md`](RESULT.md).
