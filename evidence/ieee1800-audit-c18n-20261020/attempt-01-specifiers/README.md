# IEEE 1800-2023 §18.5.2 specifiers and §18.5.3 set membership

Lead-directed audit probes. Sources are copied into `input/`; the Slurm run
uses a pinned Icarus toolchain and applies a 30-second process-group timeout to
each compile and simulation.

## Standard references

- IEEE 1800-2023 §18.5.2, pp. 530–531: constraint `:initial`, `:extends`, and
  `:final` semantics and required errors.
- IEEE 1800-2017 §18.5.2, pp. 511–512: inheritance rules before these 2023
  specifiers were added.
- IEEE 1800-2017 §18.5.3, p. 512: set-membership expressions in constraints.
- IEEE 1800-2023 set-membership expression rules are in §11.4.13.

## Dedupe

Open and closed searches for `"final constraint"`, `":extends"`,
`"initial specifier"`, and `"constraint specifier"` found closed issue #456,
which explicitly covers all three constraint specifiers. No new issue is
proposed for §18.5.2; if the probes fail, report the evidence to the lead.

## Results

See `RESULT.md` and the raw files under `remote-results/` after the Slurm run.
