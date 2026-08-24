# OpenTitan strong-eventuality package action (2026-08-24)

## Symptom

All four TL-UL error-response assertions in unmodified OpenTitan compiled with
an “Enable of unknown task `uvm_report_error` ignored” warning. Ordinary
assertions
using the same `ASSERT_ERROR` macro resolved `uvm_pkg::uvm_report_error`
correctly; only the `A and B |=> s_eventually(C)` forms lost the report.

## Root cause and fix

An unbounded strong obligation can fail either while the checker runs or at
end of simulation. `sva_clone_stmt_` therefore copies the user's action into a
synthesized final process. Its `PCallTask` copier rebuilt the path and actual
arguments but discarded `PCallTask::package()`. The copied
`uvm_pkg::uvm_report_error(...)` became an unrelated unqualified lookup for
`uvm_report_error`, which the compile-progress path replaced with a no-op.

The copier now retains the package object when it reconstructs the call. It
also refuses receiver-method calls explicitly instead of accidentally turning
one into an unqualified call; that still-unsupported action shape remains
loud.

## Evidence

- `sv_assert_strong_eos_package_action` is red on `d248f8f6e`: one unknown-task
  warning, no package call, and `FAILED -- package action calls=0`.
- The fixed compiler prints `PACKAGE ACTION tree_eventual` and `PASSED`.
- Slang 1800-2017 accepts the reducer with zero errors and zero warnings.
- The 54-test Caliptra/SVA runtime focus is 54/54.
- The NFA dual-run/gold suite is 56/56.
- A fresh compile of the unmodified OpenTitan ADC FuseSoC source list exits 0
  with zero TL-UL `uvm_report_error` unknown-task warnings, down from four.
