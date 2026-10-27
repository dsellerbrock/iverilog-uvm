# Standard basis — chandle in DPI

Checked in IEEE 1800-2017 and IEEE 1800-2023.

- §6.14 permits chandles as subroutine arguments and function results.
- §35.5.5 includes `chandle` among allowed imported-function result types.
- §35.5.6 includes `chandle` among allowed import/export formal argument
  types.
- Annex H, Table H.1 maps SystemVerilog `chandle` to C `void *`.

The existing test verifies a C pointer returned as a `chandle`, passed back
to C for reading, then passed back for freeing. Source standards are
`/Users/danielellerbrock/Documents/Standards/1800-2017.pdf` and
`1800-2023.pdf`.
