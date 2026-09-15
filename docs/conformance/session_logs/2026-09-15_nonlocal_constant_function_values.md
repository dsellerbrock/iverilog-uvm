# Nonlocal constant-function values — L105

FOCUSED_TESTED under IEEE 1800-2017 and 1800-2023 13.4.3 and6.20.2. Required broad batch gates remain pending.

A constant function reading mutable package state initialized to7 silently returned0. The evaluator no longer supplies fabricated typed defaults when package/class state is absent from the local context. A same-basename local also cannot supply the value of qualified package/class state. Genuine local defaults, synthetic receiver handling and synthesis loop contexts are preserved.

The string rejection reducer exposed a second part of the error path: typed string parameter evaluation retained an unreduced function expression and later aborted in target lowering. The typed-string parameter path now requires a constant string node, reports a counted elaboration error and stops before target emission, matching the existing untyped-string/real/integral checks. No target workaround or placeholder value was added.

Paired tests reject initialized/uninitialized package scalar/string state, same-name shadow borrowing and class-static controls; legal local/parameter/computed-string constants and runtime mutable state execute correctly. Untyped and typed string parameter paths are covered. Six synthesis-loop regressions protect the non-function evaluator callers. Initial generic lexical-function checking was narrowed after caller review to preserve those contexts.

Existing string-format nonlocal and toupper/tolower arity/type negative golds now include explicit parameter-evaluation errors and increased error counts. Their original diagnostics remain; this refresh is not another semantic feature. Failed candidate and neighbor logs are preserved.

[Revision-scoped validation](2026-09-15_nonlocal_constant_function_values_validation.json) records source/artifact hashes and the final results. Broader constant-function locality and application qualification remain incomplete.
