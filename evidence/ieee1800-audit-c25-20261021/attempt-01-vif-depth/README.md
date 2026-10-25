# Clause 25.9 virtual-interface depth probes

Lead-selected paired probes for IEEE 1800-2017/2023 §25.9. They exercise parameterized virtual-interface compatibility, modport assignment, class-held interface references, procedural task calls and event control, and the standard placement and elaboration restrictions. Existing §25.9 issues #815 and #816 remain separate: null-interface fatal behavior and continuous-assignment use.

Run each input independently with `-g2017` and `-g2023` using pinned Icarus `cc25756d1` and a 30-second process-group timeout per compile/run. Paired outcomes are in [`RESULT.md`](RESULT.md), with raw logs and status under [`raw-slurm-3762/`](raw-slurm-3762/). The fresh open-and-closed issue dedupe is in [`DEDUPE.md`](DEDUPE.md).

| Case | Input |
|---|---|
| V1 parameter-matched interface type | [`V1_parameter_match.sv`](input/V1_parameter_match.sv) |
| V2 parameter-mismatched interface type | [`V2_parameter_mismatch.sv`](input/V2_parameter_mismatch.sv) |
| V3 no-modport interface assigned to modport VIF | [`V3_modport_assignment.sv`](input/V3_modport_assignment.sv) |
| V5 class array of virtual-interface transactors | [`V5_class_array_vif.sv`](input/V5_class_array_vif.sv) |
| V7 virtual-interface task call through a class | [`V7_vif_task_call.sv`](input/V7_vif_task_call.sv) |
| V8a virtual interface as module port | [`V8a_virtual_interface_port.sv`](input/V8a_virtual_interface_port.sv) |
| V8b virtual interface as union member | [`V8b_virtual_interface_union.sv`](input/V8b_virtual_interface_union.sv) |
| V9 interface type with an outside hierarchical reference | [`V9_external_hier_reference.sv`](input/V9_external_hier_reference.sv) |
| V10 external `defparam` interface instance assigned to VIF | [`V10_external_defparam.sv`](input/V10_external_defparam.sv) |
| V12 procedural event control through a class-held modport VIF | [`V12_event_control_in_class.sv`](input/V12_event_control_in_class.sv) |
