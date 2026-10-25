# §23.4 nested module instantiation probe

## Standard basis

IEEE 1800-2017 and IEEE 1800-2023 §23.4 state: “A module can be declared
within another module” and that the outer namespace is visible to the inner
module, “provided the module is declared and instantiated in the same scope.”

## Probe

Source: [`p23_04f_nested_module_scope.sv`](../../../tests/1800_audit/c23/p23_04f_nested_module_scope.sv)

Run: `localrun 120 sh evidence/ieee1800-audit-c23d-20261020/attempt-02/run.sh`

Both `-g2017` and `-g2023` fail elaboration at the same-scope `inner u()` with
`Unknown module type: inner`. No runtime is reached. Peak RSS was 16 MiB; total
wall time was under one second.

The earlier port-connection variant is preserved as
[`nested-module-ports.sv`](nested-module-ports.sv); it failed identically. The
scope-only test is the minimal reproducer.
