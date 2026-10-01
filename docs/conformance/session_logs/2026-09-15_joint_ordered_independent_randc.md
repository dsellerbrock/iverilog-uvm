# Independent cyclic components with ordered solving — L109

FOCUSED_TESTED; broad batch qualification pending. IEEE1800-2017
18.4.2/18.5.10 and IEEE1800-2023 18.4.2/18.5.9.

Joint object-graph solving rejected every active randc property whenever an
ordering constraint existed. The runtime now uses the existing dependency
component analysis to admit independent enumerable cyclic components. Existing
randc-first sampling pins their values before ordered stages. Components that
couple cyclic and ordered/distribution references remain explicitly unsupported;
no constraints or transaction history checks are removed.

Paired scalar and fixed-array-element tests prove cyclic progression alongside
ordered distribution, UNSAT rollback, disabled mode and object constraints.
Transitive coupled rejection preserves field values; direct illegal randc
ordering remains rejected. Both focused harnesses pass eight cases.

Both neighbor harnesses pass51 of55. Four older focus-only tests have stale
compile-output expectations or an unsupported constraint call; none is in the
main manifests. These failures predate this runtime-only change: installed
compiler, driver and target hashes match L108 exactly. Their logs and unchanged
expectations are retained; this is not an all-green neighbor claim.

The [validation record](2026-09-15_joint_ordered_independent_randc_validation.json)
contains baseline, source/tool fingerprints, commands, failed build/fixture
attempts and final outputs. Coupled cyclic distributions and broader constraint
semantics remain incomplete.
