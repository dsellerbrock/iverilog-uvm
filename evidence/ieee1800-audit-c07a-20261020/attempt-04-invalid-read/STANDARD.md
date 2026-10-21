# Standard basis — superseded invalid queue-read design

Checked in IEEE 1800-2017 and IEEE 1800-2023.

- §7.10.1 says an invalid queue index returns the value for a nonexistent
  array entry of the queue element type.
- Table 7-1 in §7.4.6 (2017) and §7.4.5 (2023) specifies `X` for a
  4-state integral entry and `0` for a 2-state integral entry.
- §6.11 defines `int` as 2-state. The first probe incorrectly expected an
  invalid `int` queue read to be X; its observed zero is standards-conforming.
- The corrected probe uses `logic` for the 4-state X case and retains `int`
  and `bit` as zero-valued controls.

See the cited clause and table numbers above; source PDFs are
`/Users/danielellerbrock/Documents/Standards/1800-2017.pdf` and `1800-2023.pdf`.
