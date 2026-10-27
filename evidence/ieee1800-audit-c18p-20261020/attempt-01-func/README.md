# IEEE 1800 functions in constraints — lead-directed probe

- IEEE 1800-2017 §18.5.12, p. 521 and IEEE 1800-2023 §18.5.11 define
  constraint-function argument restrictions, state-valued function results,
  and implicit ordering for random arguments.
- Positive probes check a value function, ordering when the function result is
  further constrained, and the allowed `const ref` form. Negative probes use
  `output` and `ref` formals. Each compile/run has a 30-second process-group
  timeout under both editions.
- Open and closed issue searches for `"function in constraint"`,
  `"constraint function call"`, `"18.5.12"`, and
  `"function implicit ordering"` will be recorded after the run.

Results and raw logs will be recorded after the Slurm run.
