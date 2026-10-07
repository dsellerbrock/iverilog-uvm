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

## Variable-size enum arrays

A two-bit enum with legal values 1, 2, and 3 competes at sizes one and two,
giving three short tuples and nine long tuples. The old fallback produced
67/53 short/long results in 120 draws. The bounded exact sampler now retains
the enum literal constraint on every active element it synthesizes and keeps
inactive padding fixed at zero, even though zero is not an enum value. The
registered paired regression produces 29/91 in 120 draws. The full paired
uniformity suites passed in strict `-g2017` and `-g2023` on the build below;
the final rebuild also passed focused enum-array and enum-domain checks in both
editions.

Full-suite source-built ARM64 VVP SHA-256: `dc6b14b305259b2e6f2c59d478703ce29abf4b35ec47a6147e98e6bccdd50908`.
Final focused-check source-built ARM64 VVP SHA-256: `d6b2f92644daccc0377c71335d6b7fc655c335a41f9ab3f4b49535826c20e8a9`.

## Unconstrained large variable-size arrays

For one-bit arrays of size 512 or 513, complete-tuple sampling should choose
the sizes in a 1:2 ratio. The old fallback gave 57/63 in 120 draws. Expanding
all array elements into Z3 made the focused run correct but took 184.55 s and
153 MB. The current path leaves unconstrained element leaves out of the solver
model and weights each feasible size by its element cardinality; constrained
array leaves retain the 512-element aggregate solver-model cap. The existing
per-container allocation cap remains 65,536. At this checkpoint, feasible
size domains still had to enumerate within 1,024 values; fix 8 below removes
that limit with SAT endpoint searches.

The focused reducer now samples sizes 46/74 and produces a one in
`payload[0]` 65/120 times. It completes in 0.91 s with 35,815,424-byte maximum
RSS. The registered full regression passes under strict `-g2017` and
`-g2023` on source-built ARM64 VVP SHA-256
`a02c9f52b4001e8ec4b68f601426d1800b802bee10f350cf824327cdd9481872`:
2017 completed in 110.00 s at 42,876,928-byte maximum RSS; 2023 completed in
103.59 s at 42,188,800-byte maximum RSS. The neighboring sampling-failure and
fixed-array solve-before controls also print `PASSED` in both editions; the
failure test's warning and allocation error are expected.

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
solving, state checks, and queue-element references are absent. At the fix-8
checkpoint it supported widths through 256 bits; fix 9 below raises that cap to
4,096 bits. It reuses the existing isolated-factor proof and searches for the
first feasible value and the first infeasible value after each run. Up to
eight disjoint runs are counted by cardinality, then one uniform rank is drawn
from their union. Tautological factors use a direct full-domain draw. Unknown
solver results and unions with more than eight runs decline this path.

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


## Non-enumerable dynamic-array size intervals (fix 8)

The unconstrained-element fast path no longer enumerates every complete size
model up to the previous 1,024-value cap. It finds the minimum and maximum
feasible size with SAT binary searches, first proving that at least one size is
within the existing 65,536-element runtime allocation cap. A singleton payload
domain proposes sizes uniformly over the endpoint interval; larger integral or
enum domains use a truncated geometric offset, giving each size probability
proportional to its number of element tuples. The shared hard solver rejects
holes and coupled constraints. This is exact, though sparse accepted sizes can
require many rejections.

The registered singleton-enum regression allows sizes 0 through 1,024, so it
has 1,025 legal sizes with one tuple per size. The old complete-model path ran
for 197.55 s before its standalone probe was interrupted; it produced no
histogram, so this is an incomplete performance baseline rather than a
completed statistical failure. The first fix 8 candidate (`e11ed642a85bd92dfbeb9e4b1789ea4d542cba9aa40d6fa77e32ce836cc39fa4`) completed the focused 400-draw run in 2.63 s
at 38,633,472-byte maximum RSS, with equal-size bins `108, 99, 96, 97`. The
final candidate adds a SAT preflight for the allocation cap and is built as
`c952c79150ac27b424a34d59ec76eee5bade6a9b7b420fa1fb66a8ba14fe74f0`. The
permanent paired regression requires each bin to stay between 70 and 130.

On the same source-built ARM64 VVP image, strict `-g2017` and `-g2023` full
`sv_randomize_global_uniform` suites both printed `PASSED`. The 2023 run took
99.29 s at 46,448,640-byte maximum RSS; time and RSS were not captured for the
2017 run. The VVP SHA-256 is
`c952c79150ac27b424a34d59ec76eee5bade6a9b7b420fa1fb66a8ba14fe74f0`.
The first fix 8 candidate (`e11ed642a85bd92dfbeb9e4b1789ea4d542cba9aa40d6fa77e32ce836cc39fa4`) gave 512/513-bit array sizes `50/70` and 55 ones in
`payload[0]` out of 120, in 0.64 s at 34,947,072-byte maximum RSS. The final guarded candidate `c952c79150ac27b424a34d59ec76eee5bade6a9b7b420fa1fb66a8ba14fe74f0` passes both complete suites.

The neighboring `sv_randomize_global_sampling_fail` rollback control and
`sv_constraint_solve_before_fixed_array` regression printed `PASSED` under
both editions. The failure control's oversized-component warning and supported
allocation-limit error are expected.


## Isolated wide scalar intervals above 256 bits (fix 9)

The interval sampler's arbitrary-width integer helper already used multi-limb
arithmetic, but both it and its caller rejected widths above 256 bits. A
257-bit scalar constrained to `[1:1024]` reproduced the bias at that boundary:
with seed 628 the fallback produced equal-cardinality bins `26, 14, 26, 134`
out of 200. Raising the supported interval width to 4,096 bits gives an exact
uniform draw over the same legal interval. The same-seed 200-draw focused run
produced `40, 54, 53, 53` in 32.40 s at 37,011,456-byte maximum RSS. The
permanent paired regression uses 80 draws with four bin limits of 8–32; its
focused result is `19, 20, 17, 24`.

The final source-built ARM64 VVP SHA-256 is
`be826871789654ec476f6a0c6a68bef0b0248bbadf379e4f021b43940acdd403`. The
registered full uniformity suite printed `PASSED` under strict `-g2017` in
92.12 s at 48,824,320-byte maximum RSS and under strict `-g2023` in 88.08 s at
48,709,632-byte maximum RSS. Widths above 4,096 bits and unions with more than
eight intervals remain unsupported by the fix-9 fast exact path.

## Isolated wide scalar unions with more than eight runs (fix 10)

The eight-run ceiling sent a nine-run union to the Optimize fallback. A 33-bit
scalar constrained to nine equal 32-value intervals has 288 legal values, so
the existing 256-value enumerator cannot mask this path. With seed 910, the
old fallback returned counts `8, 6, 4, 9, 3, 3, 6, 10, 41` in 90 draws; the
last interval alone received 41 draws. Raising the exact interval cap to 16
preserves exact cardinality weighting. With the same seed and 90 draws, the
new sampler returned `12, 11, 8, 15, 8, 7, 11, 13, 5`. A 270-draw run gave
`31, 27, 33, 38, 23, 25, 29, 33, 31`. Their runtimes were 5.01 s and 14.97 s,
with 34,471,936-byte and 34,603,008-byte maximum RSS.

The permanent paired regression uses seed 629 and 270 draws, requiring each
of nine equal-cardinality bins to fall between 12 and 48. The full registered
uniformity suite printed `PASSED` under strict `-g2017` in 117.47 s at
49,283,072-byte maximum RSS and under `-g2023` in 102.49 s at 48,824,320-byte
maximum RSS. The source-built ARM64 VVP SHA-256 is
`237fbde41419504ff9734701c615f8fc3dd78fd70a5f0889f6432a8063d9f167`.
Unions with more than 16 runs and scalar widths above 4,096 bits remain outside
this exact path.

## Wide scalar boundary-query budget (fix 11)

The fixed 16-run ceiling was replaced by a total budget of 131,072 SAT checks
for interval boundary searches in one randomization call. The existing width
ceiling remains 4,096 bits; exhaustion or an unknown solver result declines
the exact path. The new registered 33-run test covers 33 equal eight-value
intervals (264 legal values, above the existing 256-value enumerator), seed
631, and 300 draws. A focused standalone reducer matching that oracle was run;
the prior fallback with the same legal set had empty bins and put
30/90 draws in its final interval. The current source-built ARM64 VVP
(`cd7ee20a7203db112a491279160d2ec351883c68731e176b4605e8513bfd5c7d`) produced
`7, 10, 8, 6, 9, 11, 11, 8, 8, 8, 14, 7, 10, 13, 4, 9, 9, 8, 5, 14, 14, 5,
4, 15, 6, 9, 9, 10, 11, 10, 9, 7, 12` in both strict editions, within the
registered 1–22/bin threshold. The focused runs took 76.07 s under `-g2017`
(37,027,840-byte max RSS) and 77.25 s under `-g2023` (36,388,864-byte max RSS).
Both full-suite sources compile under both editions, but the full suites have
not been rerun on this image. The last full-suite pass remains fix 10 above.

## Dense periodic wide scalars (fix 12)

A 33-bit scalar constrained by `value[1:0] != 2'b11` has three equally sized
legal residue classes. On the old Optimize diversity fallback, seed 632 gave
class counts `73, 74, 153` in 300 randomizations. The registered paired test
now requires each count to be between 70 and 130 and observes `100, 89, 111`
under strict `-g2017` and `-g2023`.

The sampler first tries 64 uniform full-domain candidates; the first SAT
candidate is exactly uniform over legal values and handles dense periodic
domains without counting a large number of intervals. If those proposals all
miss, exact interval counting remains available for sparse domains. If
boundary solving reaches its query cap or returns unknown, the sampler tries
up to 65,536 more uniform candidates and then fails explicitly if no exact
sample can be established. It no longer falls through to biased diversity
optimization on an indeterminate interval search.

The registered `sv_randomize_global_uniform` suite passed under strict
`-g2017` and `-g2023` on source-built ARM64 VVP SHA-256
`2c1dfe0ad2e2a82d6033192712131bc965cb82d8c7e3d6ff0790730c464a6970`.
2017 completed in 266.23 s; maximum RSS was not captured. 2023 completed in
231.86 s at 50,970,624-byte maximum RSS. The adjacent sampling-failure
rollback and fixed-array solve-before controls also printed `PASSED` in both
editions. This does not close the broader IEEE uniformity requirement.

After formatting and test-identifier cleanup, the rebuilt ARM64 VVP
`e9c40812d1d49636fcc37c26135c62710d1465b8b2d64b1c89b1e54e9f479d39` passed
the focused periodic reducer with the same `100, 89, 111` histogram. The
registered full-suite sources compile under both editions on the cleaned
source. The full suites were not rerun on this rebuilt hash.

## Constrained `randc` cycles by exact rejection (fix 13)

The old sparse-domain enumerator stopped after 64 candidates. For an 11-bit
`randc` variable constrained to `[0:127]`, it fell through to ordinary solver
sampling and repeated before completing the 128-value cycle.

The direct scalar fallback now samples uniform bit-vector proposals and
accepts only candidates that satisfy the hard solver and are absent from the
committed cycle history. A solver check with all committed values excluded
proves when the current legal set is exhausted; that reset is staged with the
successful value, so a failed solve leaves the completed cycle intact. The
sampler does not extend the feasible-set enumeration cap. It is limited to the
existing 20-bit randc history and 65,536 proposals per solve; unknown checks or
proposal exhaustion fail explicitly rather than repeating or returning a
biased candidate.

The registered regression checks two complete 128-value cycles and inserts
an unsatisfiable randomize call between them. Its focused paired strict
`-g2017` and `-g2023` run passes on source-built ARM64 VVP SHA-256
`94916a850cacd433ec7e2fc52306947eab0f2360ce4de7cb91f09ff9ef8cd8b6`.
Adjacent struct-randomization, fixed-array solve-before, and failure-rollback
controls pass in both editions. The registered uniformity suite sources
compile in both editions; the full suites were not rerun on this image. Direct
randc widths above 20 bits, exhausted proposal budgets, and aggregate randc
shapes remain open.

## Satisfiable soft constraints join uniform tuple factors (fix 14)

The reducer has two independent `rand bit` variables with
`soft (left == 0 || right == 0)`. The preference is satisfiable, so the legal
complete tuples are `00`, `01`, and `10`, each with probability 1/3. The prior
fallback gave `948,916,1136` counts in 3,000 draws; it treated the variables as
independent even though the soft expression couples them.
The registered [class and histogram check](../../ivtest/ivltests/sv_randomize_global_uniform.v)
contains this exact case.

The exact sampler now includes active explicit soft expressions while finding
tuple dependencies, then samples against the existing soft-priority-resolved
solver. Strict `-g2017` and `-g2023` both produce `945,1012,1043` in 3,000 draws
with seed 5541 on source-built ARM64 VVP SHA-256
`3b2f946d7b3463d39ac59886cda1dada0600bd76ac42328ab2279da71efdc3ab`. The prior
soft-scalar image was `504e7ff73c82d22564ee1c68c0b5852fd855767bf2e2d11f3ad9beb93aeea3c0`.

A second reducer uses a two-element `rand bit value[]` fixed by
`value.size() == 2` and the soft relation
`soft (value[0] == 0 || value[1] == 0)`. The old per-element fallback gave
`718,751,1531` across the three legal tuples in 3,000 draws. Fixed-size arrays
were not marked ready for joint sampling, even when all referenced element
variables fit under the existing 512-element solver cap. The path now handles
that bounded fixed-size case; strict 2017 and 2023 both produce
`1004,1009,987` in 3,000 draws on the image above. The registered regression
checks 300–500 per legal tuple in 1,200 draws; its matching focused run produced
`397,403,400`. Both reducers require zero occurrences of the excluded `11`.

The registered uniformity sources compile in both editions. Existing
inherited-soft, alias-soft, and source-priority controls pass 3/3 per edition.
The full registered suite remains deferred until the 10-fix batch checkpoint.

## Soft foreach over fixed array elements (fix 15)

The paired reducer uses `rand bit mode`, a two-element fixed unpacked `rand
bit` array, and `foreach (payload[i]) soft (mode == 0 || payload[i] == 0)`.
The five maximum-satisfaction tuples are `(0,00)`, `(0,01)`, `(0,10)`,
`(0,11)`, and `(1,00)`. IEEE 1800-2017 §18.5.10 and 1800-2023 §18.5.9
therefore require equal probability for those five complete tuples.

With seed `20261006`, the pre-fix runtime image
`e03e71b261bcf0f4e98cf6a67e8cae5b4a7cebd180001e961bc1db52f663c5ae` gives
`476,513,543,508,960/3000` in strict `-g2017` and `-g2023`. The current
source-built VVP image
`3b2f946d7b3463d39ac59886cda1dada0600bd76ac42328ab2279da71efdc3ab` gives
`594,590,592,612,612/3000`; the three tuples violating either soft clause are
absent in both runs. The permanent paired statistical check is in
[`sv_randomize_global_uniform.v`](../../ivtest/ivltests/sv_randomize_global_uniform.v).
Both registered suite sources compile in both editions. Full registered runs
remain deferred to the pending 10-fix checkpoint.

## Soft foreach with variable dynamic-array size preserves implicit ordering (fix 16)

This paired reducer uses `rand bit mode`, `rand bit payload[]`, ties the size
to `mode` (`mode == 1` gives one element; `mode == 0` gives two), and applies
`foreach (payload[i]) soft (mode == 0 || payload[i] == 0)`. IEEE 1800-2017
§18.5.8.1 and IEEE 1800-2023 §18.5.7.1 explicitly solve array-size
constraints before the array's iterative `foreach` constraints. The first
stage has two legal `(mode,size)` pairs, so each has probability 1/2. In the
second stage, the size-two case has four equally likely payloads; the size-one
case has only payload zero after its soft preference. Expected bins are
therefore `1/8,1/8,1/8,1/8,1/2`, not five equal bins.

With seed `20261008`, strict `-g2017` and `-g2023` both produce
`380,393,390,371,1466/3000`. The paired permanent regression verifies the two
sizes, the soft-forced size-one value, four conditional size-two bins, and the
size-first marginal. Both registered suite sources compile in both editions;
full suite runs remain deferred to the 10-fix checkpoint.

## Solve-before weighted `dist` expressions across object graphs (fix 17)

IEEE 1800-2017 §18.5.4 and 1800-2023 §18.5.3 allow integral expressions as
distribution weights. The paired regression solves `mode` before `value`,
uses `mode` to choose 1:3 or 3:1 weights, and ties the distributed value to a
child object's random property. Before this fix, the direct-object path passed
but the cross-object path rejected the weight as non-state data.

The joint sampler now retains the weight expression, connects its random
operands to the distribution subject, and evaluates each weight only after the
solve-before prefix is pinned. A zero weight still excludes its item. This
exact path currently accepts one dynamic-weight distribution per connected
component and fails closed when a weight is not proved fixed at its sampling
stage or exceeds the exact weight limit; broader dynamic-weight combinations
remain open.

The paired `sv_randomize_global_dist_components` regressions and a
direct-object probe pass under strict `-g2017` and `-g2023`. On source-built
ARM64 VVP SHA-256
`ed2d5fc0dad10b8e67ac0a30a3aa040a8fc3566a342a0f4bc2f44c48708c69a0`, the
full registered `sv_randomize_global_uniform` suite passed in 243.16 s under
2017 (49,758,208-byte maximum RSS) and 258.14 s under 2023 (49,872,896-byte
maximum RSS). The adjacent fixed-array solve-before and sampling-failure
rollback controls also passed in both editions; the latter emits its expected
oversized-domain warning and allocation-limit error before printing `PASSED`.

After a whitespace-only source alignment, the rebuilt VVP hash is
`446a7df001a1dbb7d73b46d64159d172c54f47cd746653e9b45a7d7472b0ba72`. The
paired dynamic-weight regression, direct-object probe, fixed-array controls,
and rollback controls were rerun on that binary and passed. The full suites
were not rerun after that formatting-only change.
This closes one ordered-weight case in the active batch; it does not establish
complete IEEE constraint-randomization or uniformity support.

## Graph-coupled scalar `randc` beyond full-domain enumeration (fix 18)

The paired regression couples an 11-bit `randc` property over `[0:1024]` to a
child object's random bit. The declared domain has 1,025 values, just beyond
the complete-enumeration cap of 1,024. Before the fix, the global graph path
failed with `a randc stage could not be enumerated completely`.

When enumeration is incomplete, the global path now uses the existing exact
hard-solver rejection sampler for this scalar `randc` property. Its feasibility
checks use the global hard-constraint solver, so the selected value retains a
valid child completion; cycle history remains transactionally staged. The
existing 20-bit history and 65,536-proposal limits are unchanged.

The focused reducer draws 32 unique values while preserving both constraints
under strict `-g2017` and `-g2023`; both runs print
`PASS aggregate randc 32/1025` on source-built VVP SHA-256
`9e3583a9621e33c28f75904775370d6d6648ee2d17dc4e19ee1b8589198efa40`. The
registered paired suite sources compile in both editions. Full registered
uniformity suites remain deferred to the next ten-fix checkpoint.

## Graph-coupled fixed-array `randc` leaves beyond full-domain enumeration (fix 19)

The paired permanent regression places a constrained `randc bit [10:0]`
element in a fixed unpacked array and couples its low bit to a child object's
random property. Its legal values are `[0:1024]`, so the 1,025-value feasible
set exceeds the complete-enumeration cap. Before this fix, the global graph
path failed with `a randc stage could not be enumerated completely`.

The existing exact hard-solver rejection sampler now accepts a per-leaf
history key and is used for non-nested fixed-array randc leaves. Container and
nested histories still fail closed. A focused paired reducer completes all
1,025 legal values once each, then starts the next cycle, while preserving the
child constraint under strict `-g2017` and `-g2023`. Both runs print
`PASS fixed-array graph randc full 1025-value cycle and reset` on source-built
VVP SHA-256 `f78d193df36a7ea842678392f25bc5a6637d10ee5db299d620595ae9f664a083`.
The 2023 run takes 25.41 seconds and peaks at 38,928,384 bytes maximum RSS.
The registered uniformity suite sources compile in both editions; full suite
runs remain deferred to the next ten-fix checkpoint.
