# §23.5 extern module declarations

## Standard basis

IEEE 1800-2017 and IEEE 1800-2023 §23.5 state that `extern module` declares
module ports without defining the module and permit both ANSI declarations
(including parameters) and non-ANSI port lists.

## Probe

Sources: [`p23_04b_extern_m.sv`](../../../tests/1800_audit/c23/p23_04b_extern_m.sv)
and [`p23_04c_extern_param.sv`](../../../tests/1800_audit/c23/p23_04c_extern_param.sv).

Run: `localrun 120 sh evidence/ieee1800-audit-c23d-20261020/attempt-03/run.sh`

The non-ANSI and parameterized ANSI sources both fail at their first `extern`
token with a syntax error in `-g2017` and `-g2023`. No runtime is reached. The
standard's matching-definition requirements are not reached by these probes.
