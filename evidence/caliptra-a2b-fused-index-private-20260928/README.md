# Private Caliptra A2B signed-index NBA prototype

This prototype builds on the private short packed-slice load commit
`d64544a5b076a5b5bafe8acfaee84e71122f11f9` (Caliptra compiler base
`4c45450a4448edd73ca80ffc20bdeeef69f1e788`). It has not been merged
into the shared compiler or tested in the 52-case Caliptra campaign.

## Scope

The VVP backend recognizes a narrow packed partial nonblocking assignment:
a two-bit RHS assigned at signed `2*j` or `2*j + base`, where `j` is a plain
32-bit signed scalar register and `base` is a nonnegative 32-bit constant.
The expression must have the expected widened 33/34-bit form, and the NBA
must have zero delay and no event control. The new `%assign/vec4/off/s2`
opcode reads `j` when the assignment executes and schedules one ordinary
partial NBA. It leaves the loop variable visible and preserves the number
and order of updates; it does not combine separate NBAs.

## Measurements

The pinned Adams Bridge `abr_masked_A2B_conv` plus its full-adder and AND
submodules was compiled as a standalone `WIDTH=46` design with
`real_a2b_diag_tb.sv`. The testbench drives 100 clocks, including reset
release and periodic zeroize, and records a result hash. The fused image
contains 322 new opcode sites. Eleven alternating paired runs against the
short-slice-only image gave these medians:

| Image | Wall seconds | CPU seconds | Result hash |
| --- | ---: | ---: | --- |
| Short-slice only | 0.339865 | 0.338793 | `cc373498` |
| Short-slice + fused NBA | 0.306690 | 0.305391 | `cc373498` |

The measured speedup is 1.108x wall and 1.109x CPU. Raw paired samples are
in `paired-real-a2b-fused.json`. The smaller 1000-cycle x/y and triangular
sum reducers yielded 1.016x and 1.035x wall speedups respectively; see
`paired-fused-after-part.json`. These are private, bounded measurements,
not a prediction for the complete Caliptra top.

## Correctness checks

- Strict JSON focus plus neighbors: 23/23; strict legacy focus: 4/4. The
  registered `sv_signed_two_bit_offset_nba` test runs in both 2017 and
  2023 modes. It checks in-range, out-of-range, signed boundary, X/Z, and
  force/release indices against expected full-vector values.
- `equiv.sv` and `sum_equiv.sv`: 120-cycle full four-state state comparisons
  matched the short-slice-only compiler image.
- `nba_index_base_offset.sv` with `watch_nba.c`: stdout matched exactly
  between compiler images, including 19 ordered VPI value-change callbacks
  across signed-boundary, X/Z, and force/release cases. The two saved stdout
  files document this check.
- `make -C vvp -j4`, `make -C tgt-vvp -j4`, and `git diff --check` passed.

The pinned RTL was read only. Full-top wall/CPU performance, broad compiler
regression suites, and the 52-case Caliptra campaign remain unmeasured for
this prototype. An independent semantic review and bounded full-top profile
are appropriate before integration.
