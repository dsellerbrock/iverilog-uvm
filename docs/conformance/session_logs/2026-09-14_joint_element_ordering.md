# L87 — Joint selected-element ordering

Joint solve-before stages now retain the complete property/element identity of
statically selected fixed-array integral elements. The applicable clauses are
IEEE 1800-2017 18.5.9/18.5.10 and IEEE 1800-2023 18.5.8/18.5.9.

The old rank map used only a property index and rejected all selected elements.
It now uses the existing `OrderRef(kind, index, element)` identity and maps
canonical element expressions into the same exact projection/preflight stages
as scalars. Fixed arrays of one or more elements are admitted; dynamic
containers, unrelated member/size orderings and active randc remain outside
this extension. L85 distribution and graph rollback machinery is reused.

The negative reducer also exposed a frontend defect: an out-of-range fixed
array target was warned about and dropped. A narrow check in ordering lowering
now rejects constant, rank-matched direct fixed-array targets outside their
declared ranges, using the existing canonical index calculation and diagnostic
latch. Other unsupported constraint shapes were not changed.

Ten cases passed in each ivtest harness, including nonzero and single-element
bounds, same-array identity, hand-derived staged probabilities, scalar/element
transitive order, aliases, frozen modes, weighted stages, cycle/cap rollback,
and three out-of-range declaration shapes. Thirty-one solver/transaction
neighbors passed. The old global ordering rejection fixture retains cyclic and
randc rejection, while requiring its newly supported element control to succeed.
See the [validation record](2026-09-14_joint_element_ordering_validation.json)
for exact commands, hashes, diagnostics and preserved initial failures.

The coordinator rebuilt the runtime and elaborator while explicitly retaining
the previously qualified SVA object files; the independent unfinished L86 source
was excluded from this focused candidate. The retained object hashes were
checked unchanged. This evidence does not qualify that unfinished SVA work.
Seven broad batch gates remain pending at the user-selected cadence.
