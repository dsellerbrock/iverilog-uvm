# 2026-07-27 — covergroup sampling from scope subroutines

## Starting point and reproducer

This campaign started from `origin/main` at `2e5eab5d8`, the merge of
PR #123. The existing
`repros/covergroup_sample_from_module_task.sv` compiled without a warning
but printed:

```text
sample() from a module task: 0.0% (want 100)
```

The generated VVP program proved that this was not a receiver-load
failure. The task loaded the covergroup object correctly, then emitted:

```text
%covgrp/sample 0, 0;
```

The class definition later contained the expected coverpoint and bin
metadata. The sample call had simply been lowered before that metadata
existed.

An adversarial pre-fix matrix expanded the boundary to a module task, a
module function, `with function sample` arguments, a class-embedded
covergroup behind a chained receiver, a package task, and an interface
task. Every checked family compiled silently and reported 0% rather than
the expected 50%.

## Root cause

Standalone covergroups are represented by synthesized `netclass_t`
definitions. `netclass_t::elaborate()` builds their coverpoint source,
guard, formal, bin, and cross metadata.

`PPackage::elaborate()` and `Module::elaborate()` previously elaborated
ordinary scope functions and tasks before class definitions. The special
`sample()` lowering in `PCallTask::elaborate()` therefore recognized the
receiver as a covergroup but read `covgrp_ncoverpoints() == 0`. It emitted
a legal-looking zero-input runtime operation and never revisited it after
the covergroup class was elaborated.

Initial/always-block calls were unaffected because behaviors are lowered
after classes. Class methods were also normally unaffected because a
class builds embedded-covergroup metadata before elaborating its method
bodies. The scope-subroutine ordering was the discriminating difference.

## Implementation

Package and module/interface class definitions are now elaborated in
lexical order before ordinary scope function and task bodies. The change
does not move class work across generated-scope elaboration in modules,
runtime variable initialization, gates, automatic covergroup samplers,
or user behaviors.

This preserves the existing static-initializer lexical ordering while
making complete covergroup metadata available at every ordinary
scope-subroutine call site. Existing lazy subroutine elaboration continues
to support class methods that call package/module functions or tasks.

## Permanent regression

`ivtest/ivltests/sv_covergroup_task_sample.v` checks computed coverage
values for:

- a module-scope task sampling a module covergroup;
- a module function and task sharing a `with function sample` covergroup;
- a module task sampling a class-embedded covergroup through `h.nested`;
- a package task sampling a package-declared covergroup instance;
- an interface task sampling an interface covergroup.

Every covergroup sees exactly two of four bins and must report 50%.
Explicit failure counters and the final `PASSED` marker prevent a
disappeared call or vacuous execution from passing.

The original repository reproducer now reports 100%.

## Validation

Final results:

- focused covergroup family: 7/7;
- clean build, staged install, and `make check`;
- negative diagnostics: 61/61;
- SVA legacy/NFA dual-run: 36/36;
- vendored ivtest name-diff: 3,218 total, exactly 44 expected failures,
  zero unexplained or stale failure identities;
- bundled VPI: 94/94;
- dedicated DPI subsystem: 20/20 with real DPI and zero skips;
- full UVM: 226/226 with real DPI and zero skips;
- installed and relocated `-uvm` front end: all eight scenarios pass.

The full UVM controls include `pkg_func_in_class_test` and
`static_init_order_test`, directly guarding the main risks of the
compile-time ordering change.
