# L45 — Unresolved bare task diagnostic

The pre-fix reducer calls an undeclared task, compiles with a warning and executes
its following marker in both editions. IEEE 1800-2017/2023 13.3 and 23.8.1 require
task invocation/name resolution; silent omission is not an implementation.

A one-line guard restricts the existing fallback so unresolved bare calls reach
the existing elaboration error. Qualified/indexed/class fallbacks remain open in
DD-020. The change does not replace legitimate lookup or alter runtime calls.

Permanent tests preserve forward same-scope, complete compilation-unit forward,
upward and implicit class lookup. Focused legacy 2/2 and JSON 4/4 pass; the real
UVM configuration-database class smoke compiles and runs successfully. Durable
logs and statuses are in `evidence/unresolved-task-assessment/final-focus-legacy.log`,
`final-focus-json.log` and `final-uvm-smoke.log`. Root reviewed the one-line guard,
lookup routes and test coverage; `git diff --check` passes.

This is the third focused feature in the approximately ten-feature batch. Broad
suites remain deferred by user direction. The parallel DD-021 assessment found
DD-022: selected packed-element bounds are lost for reads and writes. That
prerequisite must be resolved before relaxing dynamic mixed-driver rejection.
