# L49 — Bound indexed writes to the selected packed element

For `logic [1:0][7:0] words = 16'ha520`, writing `4'hf` to
`words[0][pos+:4]` with `pos=6` changed a sibling element. Blocking,
compound, NBA and synthesized DUT reducers reproduce the defect in both
editions. IEEE 1800-2017/2023 11.5.1 and 11.5.2 require only the overlapping
bits of the selected element to change. Compound evaluation also follows
11.4.1, including one evaluation of each index.

`NetAssign_` now carries the constant offset and width of a defined, valid
packed prefix alongside its existing absolute part-select base. Duplication
and target transport retain these bounds. VVP clips the RHS using the existing
runtime slice helper and writes only the surviving interval. NBA captures the
indices and clipped value before scheduling, preserving simultaneous sibling
updates. Compound reads select the bounded carrier before applying the
operator; two-state padding converts before arithmetic.

Synthesis reuses the existing variable part update and substitution nodes.
Constant overlap reuses the existing interval helper. Precise output analysis
respects carrier bounds without changing the default full-signal nexus map.
Source targets explicitly diagnose bounded forms they cannot yet translate;
provably in-range constant selections keep their existing translation.
Dynamic and invalid packed prefixes remain outside this write increment.

Root review found gaps in plain array-word stores, constant compound stores,
and a zero-base NBA whose selected width equals the full signal width. Cheap
reducers record incorrect values and a compiler assertion in
`l49-review-static-red.json` and `l49-review-wide-nba-red.json` under
`evidence/dynamic-mixed-driver-assessment`. The fixes route constant compound selections through the existing bounded
path, evaluate the blocking array base into its index register, and retain
carrier clipping for zero-base NBA writes. Permanent assertions cover all
three findings. Focused legacy 4/4 and JSON 8/8 pass in the revised candidate;
negative language checks still reject in both editions. Source-target and
sensitivity controls also pass. No full regression qualification is claimed.

An independent generated matrix checks 228 blocking, XOR compound and NBA
combinations per edition across both packed elements, bases -6 through 12,
and scalar/unpacked-array destinations. All pass; results are in
`l49-review-boundary-matrix.json`. This is the seventh focused increment.
