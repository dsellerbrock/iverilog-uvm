# Standard basis

Checked in IEEE 1800-2017 and IEEE 1800-2023.

- §35.5.6.1 permits an open-array formal whose unsized unpacked dimensions
  take their ranges and sizes from the actual argument.
- Annex H.7.4 maps the basic `string` type; Annex H.7.8 says an unpacked array
  passed to an open-array formal has C-compatible representation when the
  element type is not a 2- or 4-state scalar or packed type.
- The probe only asks `svDimensions` and `svSize`; it does not test string
  element marshaling/access.

Source PDFs: `/Users/danielellerbrock/Documents/Standards/1800-2017.pdf` and
`/Users/danielellerbrock/Documents/Standards/1800-2023.pdf`.
