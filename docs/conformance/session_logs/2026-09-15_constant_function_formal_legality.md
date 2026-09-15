# Constant-function formal legality

IEEE1800-2017 and2023 13.4.3 prohibit output, inout and ref formals in constant functions, including const ref. Previously a nested constant call could accept these declarations and fold using the evaluator's input copies.

The shared call path now classifies formal directions before consulting cached constant-function state. Runtime calls mark affected functions nonconstant without rejecting their legal runtime semantics; a required constant call emits a focused diagnostic. Qualified/static paths apply the same check before argument mapping.

[Focused evidence](2026-09-15_constant_function_formal_legality_validation.json) records paired constant inputs, nested helper calls, all four prohibited directions and runtime output/inout/ref/const-ref behavior, plus neighboring string and function tests. Exact diagnostic cascades are retained. Broad batch qualification remains pending.
