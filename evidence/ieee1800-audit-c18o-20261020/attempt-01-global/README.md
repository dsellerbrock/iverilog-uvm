# IEEE 1800 global constraints — lead-directed probe

- IEEE 1800-2017 §18.5.9, p. 517 and IEEE 1800-2023 §18.5.8 define global
  constraints and the active random-object set.
- The probe follows the standard's heap example and adds rand/non-rand child
  controls. It will run under `-g2017` and `-g2023`, with a 30-second timeout
  per compile and simulation.
- Dedupe searches for `"global constraint"`, `"rand object handle constraint"`,
  `"sub-object randomize"`, and `"18.5.9"` will be recorded after the run.

Results and raw output will be recorded after the Slurm run.
