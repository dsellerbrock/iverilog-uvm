# Clause 23.11 bind probes

Lead-selected paired probes for IEEE 1800-2017/2023 §23.11 and Syntax 23-9. They cover design-wide module targets, an explicit target list, a single instance target, a target's internal signal, a bound module containing an assertion, parameter overrides, a bind declared in the parent scope, an interface instantiation bound into an interface, and the prohibited module instantiation into an interface target.

Run B1-B8 and NB independently with `-g2017` and `-g2023`, `-gassertions`, and the pinned Icarus `cc25756d1` build. Each compile and simulation has a 30-second process-group timeout. Paired results are recorded in [`RESULT.md`](RESULT.md); the fresh open-and-closed issue dedupe is in [`DEDUPE.md`](DEDUPE.md).

| Probe | Input |
|---|---|
| B1 design-wide module target | [`B1_type_wide.sv`](input/B1_type_wide.sv) |
| B2 explicit target instance list | [`B2_type_instance_list.sv`](input/B2_type_instance_list.sv) |
| B3 single instance target | [`B3_instance_target.sv`](input/B3_instance_target.sv) |
| B4 target internal signal | [`B4_internal_signal.sv`](input/B4_internal_signal.sv) |
| B5 bound module assertion | [`B5_bound_assertion_module.sv`](input/B5_bound_assertion_module.sv) |
| B6 bound parameter override | [`B6_parameter_override.sv`](input/B6_parameter_override.sv) |
| B7 bind declared in top scope | [`B7_local_scope.sv`](input/B7_local_scope.sv) |
| B8 interface into interface target | [`B8_interface_target.sv`](input/B8_interface_target.sv) |
| NB module into interface target | [`NB_module_into_interface.sv`](input/NB_module_into_interface.sv) |
