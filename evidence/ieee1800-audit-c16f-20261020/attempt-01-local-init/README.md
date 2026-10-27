# IEEE 1800 §16.13.7 local-variable initialization probe

This is a reduced form of the two-semantic-leading-clock example in IEEE
1800-2017/2023 §16.13.7. The parent assertion begins an instance of named
property `p`; its two subproperties are governed by `clk1` and `clk2`. The
initializer expression `e` is 1 at the first `clk1` tick and 0 at the first
`clk2` tick. The `a == v` and `d == v` checks distinguish per-clock copies
initialized at those separate ticks from one shared or early-initialized copy.

The exact paired-edition compiler/run outcomes, host/tool versions, and
checksums will be recorded in `RESULT.md` after the Slurm run. No expected
output or simulator code is changed.
