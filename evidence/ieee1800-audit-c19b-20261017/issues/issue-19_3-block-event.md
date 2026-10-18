Clause: IEEE 1800-2017/2023 §19.3, Syntax 19-1.

Requirement: `coverage_event` permits `@@(block_event_expression)`; an `end` block event is triggered after the named task executes its last statement.

Probe: `tests/1800_audit/c19/p19_03_block_event.sv`, compiled with `-g2017` and `-g2023` using Icarus 13.0 devel at source `9b5fad2af`. Raw output: `evidence/ieee1800-audit-c19b-20261017/attempt-02/results/combined.txt`.

Observed: both editions report syntax errors for the valid `@@(end t1)` event, then abort with `pform.cc:2723: failed assertion lexical_scope == cur_module` (exit 134).

Expected: compile and sample once at the end of each `t1()` call. The compiler assertion is an additional crash exposed by the same minimal reproducer.
