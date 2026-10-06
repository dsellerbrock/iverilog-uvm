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
one coupled component, and fixes inactive padded elements to zero. It supports
one or more direct integral dynamic arrays whose combined maximum size is at
most 128 elements. Larger aggregate domains, absent element references, and
other excluded shapes remain outside it. The paired strict `-g2017` and
`-g2023` runs each passed the five-bin 70–130/500 oracle and the existing
scalar and fixed-size controls. The adjacent oversized-domain/failure-rollback
regression also passed in both editions.

A second paired oracle includes size zero, one, and two with unconstrained
active elements. Its eleven complete tuples each landed within 20–70/500 in
both editions, exercising canonical padding when the selected array is empty.

A third paired oracle couples two arrays through a mode bit. It has twelve
complete legal tuples across the two size configurations; all twelve landed
within 20–70/500 in both editions.

A fourth paired oracle compares size-64 and size-65 one-bit arrays. Their
complete tuple counts differ by 2:1, and the observed mode counts stayed within
70–130 and 170–230 of 300 in both editions. Peak resident memory was 44,875,776
bytes in 2017 and 44,892,160 bytes in 2023; each run completed in about 31 s.

Source-built ARM64 VVP SHA-256: `39c2d208c6cd8bb92fb989b91e86c84b0143310062e520ecb8962b7c27cf8553`.

## Variable-size arrays through 512 combined elements

A size-128/size-129 one-bit dynamic array has twice as many complete legal
payload tuples at size 129. With the former 128-element cap, the size-128 mode
appeared 139/300 times instead of about 100/300. The first extension raised
the combined cap to 256; the paired regression now gives 91/209 in 300 draws.
Canonical zero padding represents each legal array value once, and uniform
whole-tuple rejection preserves the 2:1 size weighting.

The next boundary exposed the same issue: with size 256 versus 257, the old
fallback produced 166/134 in 300 draws instead of about 100/200. The combined
cap is now 512. The registered paired regression requires 24–56 size-256
results and 64–96 size-257 results in 120 draws; a focused run produced 44/76.
This keeps the sample count moderate because 257-element solves are slower than
129-element solves.

The full `sv_randomize_global_uniform` suite passes under strict `-g2017` and
`-g2023` with the extension. The focused 256/257 probe used about 66 MB RSS; the paired full suites were
observed near 80 MB RSS.

Source-built ARM64 VVP SHA-256: `18b536ad006a8e6b01f23a930f9df13e298d117a961763058fbe96565abd5c1d`.

## Connected wide-scalar finite-domain slice

A 65-bit scalar reproducer has five complete legal tuples: one mode selects
value zero, while the other mode selects values one through four. The previous
per-property path produced `505, 122, 128, 117, 128` over 1,000 draws, instead
of about 200 per tuple. Sampling a connected wide scalar's complete feasible
unary domain when that domain has at most 64 values, then rejecting against the
full component, produced `192, 201, 202, 196, 209` with the same seed.

The registered combined scalar/array regression, including its five-bin
140–260/1,000 oracle, passed under strict `-g2017` and `-g2023`. The adjacent
oversized-domain/failure-rollback control also passed in both editions. The
separate struct-member oracle covers its tested three-tuple case but does not
qualify all member shapes. Wide domains above the enumeration cap remain open.

Source-built ARM64 VVP SHA-256: `0489a4df64e0e4af251b899f5904462351b9cdaa135e1ce2e668131af67ae271`.

A second 65-bit scalar oracle has 65 legal complete tuples: 64 select mode one
and one selects mode zero. With the previous 64-value enumeration cap, the
paired regression sampled mode one 49/100 times. Raising the cap to 128 lets
the solver enumerate the complete unary domain; the same deterministic-seed
regression now passes its mode-one minimum of 90/100 (the uniform expectation
is 64/65). Both strict editions pass. This does not claim exact wide-domain
sampling above 128 values.

Source-built ARM64 VVP SHA-256 after the cap change:
`140e55df9d08957ee9019955216cb016c3c988bfec8e5589af0635e74de48ccf`.

## Fixed unpacked-array complete tuples

The paired regression adds a fixed two-element unpacked `bit` array with five
legal tuples: mode one permits only payload `00`, while mode zero permits all
four payload values. Before adding the array elements to complete-tuple
sampling, the constrained mode appeared 161/500 times. The new histogram
requires each of the five tuple bins to land within 70–130/500; it passes under
strict `-g2017` and `-g2023`. The adjacent oversized-domain/failure-rollback
and solve-before fixed-array regressions also pass in both editions.

Source-built ARM64 VVP SHA-256 after the fixed-array slice:
`bbabbf9a1d5c8c51dca2257007ca605f52dfccdc15b7e5069c61f249da717f51`.

### Fixed arrays larger than the former 128-element cap

The new oracle declares `rand bit payload[129]` but constrains only the first
two leaves. The five projected tuples still have equal multiplicity across all
129 leaves because the other 127 bits are unconstrained. Before this change,
the declared-size cap selected the non-uniform fallback, which chose mode one
155/500 times. The updated sampler includes only leaves already referenced by
constraints; `randomize_cobject_` independently prefills the untouched leaves.

The deterministic bins are 91, 119, 90, 98, and 102 of 500 in both strict
editions. The full `sv_randomize_global_uniform` suite and the neighboring
sampling-failure and fixed-array solve-before regressions pass under both
`-g2017` and `-g2023`.

Source-built ARM64 VVP SHA-256 after referenced-leaf sampling:
`883423bbd8a32938387944ea7b14b7b0388636e263eb0a04d92375bc3cf58334`.

### Multidimensional fixed unpacked arrays

The new 2×2 fixed-array oracle has 17 legal tuples: mode one forces all four
bits to zero, while mode zero permits all 16 payload patterns. Before widening
the fixed-array eligibility guard, the mode-one tuple appeared 267/1,000 times.
The paired strict `-g2017` and `-g2023` runs now put every tuple between 30 and
90/1,000; observed bins were 54, 67, 59, 65, 58, 60, 69, 66, 52, 56, 53, 56,
56, 48, 57, 55, and 69. The full `sv_randomize_global_uniform` suite and the
neighboring sampling-failure and fixed-array solve-before regressions also
pass in both editions.

Source-built ARM64 VVP SHA-256 after multidimensional fixed-array sampling:
`8c9a705bb46707560a7c7e751f39ca201db840668ed776e8fc30d0e43e262643`.

### Connected wide unary domains above 128 values

A 65-bit scalar forms 129 legal tuples: mode zero has only value zero, while
mode one has values 1 through 128. With the previous 128-value enumeration
cap, the old fallback selected mode one 520/1,000 times; on the registered
seed it selected mode one 101/200 times. Raising the complete unary-domain cap
to 256 lets the joint sampler enumerate and rejection-sample the whole tuple.
The paired strict `-g2017` and `-g2023` runs both select mode one 196/200 times,
above the regression minimum of 185/200. The registered full uniformity suite
and its sampling-failure and fixed-array solve-before neighbors pass under both
editions.

Source-built ARM64 VVP SHA-256 after 129-tuple wide-domain sampling:
`b75832e27ccedb5dd5010d42e9430cb3ec2dd3c53e7d608cce9e2074d15980c9`.

### Connected wide domains above the enumeration cap

A connected 65-bit property has one mode with value zero and another with any
nonzero value, for 2⁶⁵ legal tuples. Before full-width rejection, mode one
appeared 150/200 times. The sampler now draws a uniform candidate over the
entire 65-bit domain, combines it with a uniform mode candidate, and rejects
the whole tuple against the hard constraints. Both strict editions selected
mode one 200/200 times. The sampler still enumerates complete wide unary
domains through 256 values first, which avoids full-width rejection for the
129-tuple bounded case. Rejection is exact for larger connected domains but can
take impractically many retries when the feasible set is sparse.

The registered full `sv_randomize_global_uniform` suite and its neighboring
sampling-failure and fixed-array solve-before regressions pass under both
editions.

Source-built ARM64 VVP SHA-256 after full-width wide-domain proposals:
`6fd24e3bcf95389846b13b22f719922fa7b5906456f1b9e1a3a173b5f5f05aa5`.

## Adjacent 128-bit nested fixed-element randomization

The existing `sv_constraint_wide_fixed_element_diversity` regression uses a
128-bit fixed-array element through a nested class handle. Removing the stale
64-bit metadata rejection exposed a second limit: exact tuple extraction is
64-bit. Plain unweighted components wider than that now use full-width random
candidate pins and model-value pins, allowing the diversity and same-seed
replay checks to pass under both `-g2017` and `-g2023`.

Both runs print `PASSED` and emit the existing warning that an oversized
ordinary component is sampled against the hard constraints, not uniformly over
its solutions. This runtime-support result does not qualify nested member
uniformity or sparse/unconnected wide domains above the 256-value cap; the
connected dense case is separately covered above. The
paired `sv_randomize_global_uniform` statistical suite and its rollback
control also pass on the same VVP image.

Source-built ARM64 VVP SHA-256: `3d24d2efddd12f07ad7bedbee2d8d3d6662e6af2ccffda6639ada3a35e000ccb`.

## Isolated wide-scalar interval unions

A direct `rand bit [64:0] value` constrained to `[1:1024]` previously fell
through finite-domain enumeration to Optimize diversity. With seed 626, the
registered regression failed at 23/200 in its first 256-value bucket. The new
path applies only to isolated direct scalar properties wider than 32 bits and
at most 256 bits when solve-before, `dist`, soft constraints, `randc`, exact-joint
solving, state checks, and queue-element references are absent. It reuses the
existing isolated-factor proof and searches for the first feasible value and
the first infeasible value after each run. Up to eight disjoint runs are counted
by cardinality, then one uniform rank is drawn from their union. Tautological
factors use a direct full-domain draw. Unknown solver results, unions with more
than eight runs, and widths above 256 decline this path.

### Fragmented wide-scalar intervals

Before this extension, a two-range probe with equal 512-value intervals and
seed 627 failed at 22/200 in its first bucket. The registered paired
regression now uses the unequal union `[1:768] U [1025:1280]` (1,024 legal
values total) and partitions it into four 256-value bins. All four bins stay
within 30–70/200 under both strict `-g2017` and `-g2023`, showing equal weight
per legal value across intervals with a 3:1 size ratio; results in the gap or
outside the union fail immediately. The sampler caps the exact union proof at
eight runs and 256 bits.

The registered `sv_randomize_global_uniform` suite passes under both strict
`-g2017` and `-g2023`. A same-seed standalone run gives the four equal
256-value bins `57, 54, 37, 52` out of 200 in each edition; the permanent
regression requires every bin to be 30–70. The paired 2×2×2 fixed-array
oracle has nine complete legal tuples and keeps each count within 12–55/300
under strict `-g2017` and `-g2023`; it checks that
the existing flat-storage sampler works through three unpacked dimensions.
Fixed-array ranks above three and other untested shapes remain outside the
recorded scope. The adjacent sampling-failure and fixed-array solve-before
controls pass in both editions. The oversized-domain warning and fixed-array
allocation error in the failure control are expected.

Paired full-suite commands, from the repository root:

```sh
local-install/bin/iverilog -g2017 -s main -I ivtest -o /tmp/sv-randomize-uniform-2017.vvp ivtest/ivltests/sv_randomize_global_uniform.v
vvp/vvp -n /tmp/sv-randomize-uniform-2017.vvp
local-install/bin/iverilog -g2023 -s main -I ivtest -o /tmp/sv-randomize-uniform-2023.vvp ivtest/ivltests/sv_randomize_global_uniform_2023.v
vvp/vvp -n /tmp/sv-randomize-uniform-2023.vvp
```

The latest source-built ARM64 VVP SHA-256 is recorded above; the earlier
interval-only image was `e03e71b261bcf0f4e98cf6a67e8cae5b4a7cebd180001e961bc1db52f663c5ae`.
This focused fix does not close the broader uniform-legal-combinations
requirement.
