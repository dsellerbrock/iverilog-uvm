# Standard basis — invalid queue reads

Checked in IEEE 1800-2017 and IEEE 1800-2023.

- §7.10.1 says an invalid queue index returns the value for a nonexistent
  array entry of the queue element type.
- Table 7-1 in §7.4.6 (2017) and §7.4.5 (2023) specifies `X` for a
  4-state integral entry and `0` for a 2-state integral entry.
- §6.11 identifies `int` as 2-state; `logic` is 4-state. Thus an invalid
  `logic` queue read should be unknown, while invalid reads from `int` and
  `bit` queues should return zero. Empty `logic` queue index 0 is nonexistent.

Source PDFs: `/Users/danielellerbrock/Documents/Standards/1800-2017.pdf` and
`1800-2023.pdf`.
