# L65 — Multiple fixed-array prefixes in constraint reductions

Active blocker: CONSTRAINT-MULTIPREFIX-REDUCTION. Base localmain9ad50ce52, branch agent/constraint-multidim-reductions-20260914, existing campaign worktree. No new worktree or clone.

IEEE1800-2017 7.12.3/18.5.8.2 and IEEE1800-2023 7.12.3/18.5.7.2 were read independently from local standard texts. Selecting all but the last fixed unpacked dimension yields an integral array whose reduction retains the element/with-expression result type.

The original mixed-bound rank-three state-row reproducer was rejected in both modes. Independent rank-three/rank-four active-row cases also failed. Lowering admitted at most one prefix and computed only its stride contribution. The fix processes each constant prefix against its own declared range and accumulates its exact trailing-dimension stride, with checked offset arithmetic. The existing five-method reduction body preserves width/sign, iterator/index binding and exact active/state element identities. Existing rank, constant-prefix and bounds diagnostics remain focused; runtime-selected prefix support is unchanged.

The first build caught use of vector indexing on the prefix std::list; the loop now uses list iteration plus a dimension counter. Independent test review corrected undeclared default iterator references to the explicitly named iterator; revised prebuild evidence is separately preserved. No failing or invalid test output was blessed.

Validation: root original2/2 paired checks; independent rank-three and rank-four4/4 positive runs; independent paired negative cases retain exactly3 diagnostics each for partial rank, OOB later prefix and nonconstant later prefix. Eight permanent cases pass in each legacy/JSON harness with stable compiler/runtime fingerprints, no failures/skips/expected failures. Six affected neighbors pass in each harness. Permanent tests cover refreshed state, all five reductions, mixed direction/nonzero/negative bounds, last-dimension index(), width/signedness, selected active rows, inactive neighbors and failed-solve rollback.

Evidence: evidence/constraint-multidim-reductions-l65/{baseline.json,root-after.json,permanent.json,neighbors.json,review/}. Compiler-only change; no grammar/runtime changes. Full suite is deferred until approximately ten focused features per user cadence. Broad qualified baseline remains L64/9ad50ce52; L65 is IMPLEMENTED with focused qualification, not an exact-current full-suite claim.
