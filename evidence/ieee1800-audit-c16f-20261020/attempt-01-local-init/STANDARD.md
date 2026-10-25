# IEEE 1800 standard basis — local-variable declaration initialization

IEEE 1800-2017 §16.13.7 (printed p. 455) and IEEE 1800-2023 §16.13.7
(printed p. 475) state that initialization assignments for local variables
in named sequences and properties occur when an evaluation attempt begins or
at the earliest corresponding semantic-leading-clock tick. Where a named
property has multiple distinct semantic leading clocks, the standard requires
a separate local-variable copy for each clock, initialized at its first tick.

The standard's example declares `logic v = e;` in a property with `clk1` and
`clk2` semantic leading clocks, then checks `v` in each subproperty. The
reproducer follows that example and makes `e` differ at those two first ticks.
