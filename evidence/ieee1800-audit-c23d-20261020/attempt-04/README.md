# §23.10 defparam precedence

IEEE 1800-2017 and IEEE 1800-2023 §23.10 state that when a `defparam`
assignment conflicts with an instance parameter assignment, the parameter
takes the `defparam` value. Probe:
[`p23_10a_defparam_precedence.sv`](../../../tests/1800_audit/c23/p23_10a_defparam_precedence.sv).

Both editions compile and run under `localrun 120`; each prints
`PASS: defparam precedence`.
