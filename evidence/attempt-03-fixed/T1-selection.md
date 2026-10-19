# #680 T1 selection

Graphify query: `How are inline constraint function calls lowered and where are standalone package functions captured as randomize-time values?`

The graph points to `elaborate.cc` constraint lowering and the `Z3Builder`/VVP constraint path. The change modifies function-name resolution and caller-value capture in `pexpr_to_constraint_ir`, so T1 runs the complete constraint-function area in both runners: `ivtest/regress-constraint-functions-legacy.list` and `ivtest/regress-constraint-functions.list`. The new regression is paired for 2017 and 2023 and checks that a module-scope string argument is resampled on successive randomizations. T0 separately runs the exact issue reproducer and the repository smoke set.
