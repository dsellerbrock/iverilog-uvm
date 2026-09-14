# L53 — Diagnose unresolved calls on proven hierarchy scopes

A call such as `dut.missing()` on an existing module instance compiled with a
warning and continued execution. The frozen-candidate reducer in
`evidence/unresolved-task-assessment/unindexed-hier-frozen-candidate.json`
records this in both IEEE modes.

IEEE 1800-2017/2023 13.3, 23.6 and 23.8.1 require task enables to resolve to
the appropriate task and transfer control; an unresolved hierarchy call is
not a successful no-op. Receiver-only lookup now covers unindexed dotted
paths as well as indexed hierarchy. It marks only proven non-class,
non-package scope receivers. After existing task, method and function lookup
fails, such calls use the existing unknown-task error.

Package resolution retains its dedicated path. Object values and class
scopes retain method lookup. The implementation does not diagnose based only
on path length, and it does not claim that every remaining object or
compile-progress fallback is implemented.

Focused legacy 13/13 and JSON 24/24 pass, including both editions and package,
indexed-hierarchy, index-error and inherited method controls. The permanent
positive initializes its state, uses case comparisons to reject unknown
results, and declares the child module after the caller. It proves task delay,
copy-out, void/nonvoid function effects and selected-instance state. The
negative test rejects an unresolved task on an existing instance.

Incremental build/install and root source/test review pass. Final direct
results are in `evidence/unresolved-task-assessment/l53/direct-final.log`;
focused harness logs are in the same directory. This is the first focused
feature after the qualified L43–L52 batch. Full suites remain deferred until
approximately ten new focused features.
