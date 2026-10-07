# IEEE 1800-2023 scalar `rand real`

## Scope

IEEE 1800-2023 §18.4 permits scalar class `rand real`; §18.5.9 permits real
solve-before operands. Strict IEEE 1800-2017 continues to reject `rand real`.
This increment implements the tested finite scalar subset end to end: real
literal/property lowering, binary64 constraint expressions, finite interval
sampling, solve-before staging, writeback, and rollback on failure.

The permanent reducer is
[`sv_constraint_rand_real_2023.v`](../../ivtest/ivltests/sv_constraint_rand_real_2023.v).
It checks open interval bounds, a real comparison tied to an integral random
bit, `solve value before lower_half`, 2,048 draws with an equal-half frequency
oracle, and failed-call rollback. The observed lower-half count is 1,004/2,048.
Paired negative fixtures preserve strict 2017 rejection and reject 2023
`randc real`.

This does not close the real-valued randomization clause. `randc real`,
`shortreal`, real arrays/aggregate leaves, real `dist`, and joint class-graph
real solving remain unsupported and fail closed. Only the finite scalar path
is qualified here.

## Build and focused checks

The source-built ARM64 image was built and installed with the repository's
standard `make -j4` / `make install` flow. From `ivtest/`, strict paired focus
lists pass:

```sh
PATH="$PWD/../local-install/bin:$PATH" perl ./vvp_reg.pl regress-rand-real-focus-legacy.list
# Total=3, Passed=3, Failed=0

PATH="$PWD/../local-install/bin:$PATH" python3 ./vvp_reg.py regress-rand-real-focus-vvp.list
# Ran 3, Failed 0
```

The legacy and JSON/VVP harnesses each cover the 2023 positive test, the
2017-negative test, and the 2023 `randc real` negative test. The positive test
also checks state preservation when contradictory inline constraints fail.
No broad regression suite or OpenTitan/Caliptra corpus was run for this change.

## Source-built image

SHA-256:

| File | SHA-256 |
|---|---|
| `local-install/bin/iverilog` | `9fff8e65fdf17051bb3f78b445304d705688495c251eaf7f7f31920e6935dbcc` |
| `local-install/lib/ivl/ivl` | `9bcd7a374cc4838a4997064519fd3f33997faba274294a74e752fff4eb5f2b57` |
| `local-install/bin/vvp` | `ec9bea6ad26b84556f8bc800b1176f884ef0a141f47754e8ed1bcee9eebe4d13` |
| `local-install/lib/ivl/vvp.tgt` | `404a3620fc341d4746a77d7f89086505ccbbf35a7a95832b896ab32b3138dfb1` |
