# IEEE 1800 constraint guards — lead-directed probe

- IEEE 1800-2017 §18.5.13, pp. 522–524; IEEE 1800-2023 §18.5.12 define
  guard predicates and the four-state FALSE/TRUE/ERROR/RANDOM evaluation.
- The probe reproduces the standard's Examples 1 and 2, with randomized
  operands and null-handle evaluation. It runs under both editions with a
  30-second process-group timeout for compile and simulation.
- Open and closed issue searches for `"constraint guard"`,
  `"null handle constraint"`, `"18.5.13"`, and `"guard expression"` will be
  recorded after the run.

Results and every runtime warning/error will be recorded after the Slurm run.
