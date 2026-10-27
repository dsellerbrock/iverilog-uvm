# §23.7 dotted-name resolution

IEEE 1800-2017 and IEEE 1800-2023 §23.7 say dotted names are classified by
resolving the first component: a data object selects a member; a scope name
starts a hierarchical name. Probe:
[`p23_07a_dotted_name_resolution.sv`](../../../tests/1800_audit/c23/p23_07a_dotted_name_resolution.sv).

Both editions compile and run, printing `PASS: dotted name resolution` for a
packed-struct member select and an instance-path variable reference.
