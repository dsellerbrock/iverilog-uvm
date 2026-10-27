# Standard basis — pure imported functions

Checked in IEEE 1800-2017 and IEEE 1800-2023.

- §35.5.1.3 distinguishes the `pure` and `context` import properties and says
  an imported task cannot be declared pure.
- §35.5.2 allows only nonvoid functions without output/inout arguments to be
  pure; their results depend only on inputs, and they have no side effects.
  The simulator may eliminate or reuse calls when optimizing.

The probe checks legal pure-function declarations and calls with integer
inputs/results, not optimization or every side-effect restriction. Source PDFs
are `/Users/danielellerbrock/Documents/Standards/1800-2017.pdf` and
`1800-2023.pdf`.
