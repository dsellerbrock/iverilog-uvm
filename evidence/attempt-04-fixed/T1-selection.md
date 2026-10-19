# #680 T1 selection

Graphify points from inline constraint expression lowering to `pexpr_to_constraint_ir` and the constraint-function value-slot path. The change expands standalone/package function lookup and narrows which arguments can be captured before solve. T1 therefore runs every legacy and JSON constraint-function test in both editions, including a negative pair that proves `this.data` cannot be sampled as caller state. T0 runs the issue reproducer in both editions and the standard smoke gate.
