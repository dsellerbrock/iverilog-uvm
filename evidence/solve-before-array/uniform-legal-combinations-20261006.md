# Uniform legal-combination sampling — 2026-10-06

The unordered class-B regression (`rand bit s; rand bit [31:0] d; s -> d == 0`)
failed before the fix at 61 `s == 1` results in 256 draws. The current paired
2017 and 2023 regression passes. It checks at most 10 unordered `s == 1`
results and 90–166 ordered results in 256 draws; the ordered control keeps the
approximately even marginal required by `solve s before d`.

The change rejection-samples complete tuples for coupled active direct scalar
class properties of widths 1–64 when solve-before, `dist`, soft constraints,
`randc`, containers, member properties, and symbolic state checks are absent.
Independent factors are split with `z3_joint_components_`; if that analysis
cannot prove a split, the sampler checks the whole active scalar tuple. Each
candidate is uniform over the bit-vector domain, and only solver-accepted
tuples are committed. The owning object RNG is used. Unsupported shapes remain
outside this implementation and keep the broader blocker open.

Paired commands, run from the repository root:

```sh
local-install/bin/iverilog -g2017 -s main -I ivtest -o /tmp/uniform-2017.vvp ivtest/ivltests/sv_randomize_global_uniform.v
local-install/bin/vvp /tmp/uniform-2017.vvp
local-install/bin/iverilog -g2023 -s main -I ivtest -o /tmp/uniform-2023.vvp ivtest/ivltests/sv_randomize_global_uniform_2023.v
local-install/bin/vvp /tmp/uniform-2023.vvp
```

Both runs printed `PASSED`. VVP SHA-256: `d1303bdda33e75fa7b33a70e6e8e67278abb9e520dc19617894e505eae671519`.

The adjacent `sv_randomize_global_sampling_fail` regression also printed
`PASSED` under both editions. Its expected oversized-domain warning and
unsupported-size error remained; it checks failure value/callback atomicity,
bounded joint sampling, `dist`, and solve-before behavior. It does not qualify
those excluded paths for uniform legal-tuple sampling.

## Fixed-size dynamic-array subset

The registered `ivtest/ivltests/sv_randomize_global_uniform.v` regression now
also checks the two-element dynamic-array reproducer from
[`dynamic_array_order.sv`](dynamic_array_order.sv). It asserts unordered
`m == 1` at no more than 3/128 draws and the `solve m before q` control between
40 and 88/128. The source-built ARM64 VVP passed the combined scalar and
dynamic-array regression under strict `-g2017` and `-g2023`; both runs printed
`PASSED`.

The sampler admits only active direct scalar properties plus every active
in-range integral element of a one-dimensional dynamic array materialized by
the constraints whose size tuple has exactly one solver-proven value. It
compares the actual active element indices with the expected index set and declines the path for absent elements,
unsupported widths, `randc`, ordering, soft constraints, `dist`, member state,
or other unsupported container shapes. Broader IEEE uniformity remains open.

## Bounded variable-size dynamic-array slice

The paired regression also checks one-dimensional `rand bit payload[]`, with
size one when `short_case` is true and size two otherwise. The short case
requires `payload[0] == 0`; the long case leaves both bits free. This produces
five complete legal tuples: one short tuple and four long tuples. A pre-fix
source-built run selected the short case 508/1000 times, although uniform
complete tuples require about 200/1000.

The sampler now enumerates feasible sizes, samples size and active elements in
one coupled component, and fixes inactive padded elements to zero. This slice
supports one direct integral dynamic array with a maximum size of 64 elements;
arrays with maximum sizes above 64, multiple variable-size arrays, absent element references,
and other excluded shapes remain outside it. The paired strict `-g2017` and
`-g2023` runs each passed the five-bin 70–130/500 oracle and the existing
scalar and fixed-size controls. The adjacent oversized-domain/failure-rollback
regression also passed in both editions.

A second paired oracle includes size zero, one, and two with unconstrained
active elements. Its eleven complete tuples each landed within 20–70/500 in
both editions, exercising canonical padding when the selected array is empty.

Source-built ARM64 VVP SHA-256: `4b882f566d0b6dc99ff9adca76e9fdcc6fb68a0a218f8896f5e99dfa9f9d9e08`.
