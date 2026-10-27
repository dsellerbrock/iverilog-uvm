# IEEE 1800 property-operator probes

This audit tranche probes named property instantiation, a sequence used directly as a property, property negation, if-else selection, and overlapping/nonoverlapping implication in both editions. The negative control checks a mismatched `endproperty : label`. Clauses 16.12.4–16.12.5 are outside this tranche.

Initial Slurm job `3203` compiled both probes in `-g2017` and `-g2023`. The mismatched `endproperty` label unexpectedly compiled and ran with exit 0 in both editions. The positive test's operators all behaved as expected, but its extra `cover property` action-counter check reported zero sequence hits; that counter is not a valid test oracle for this feature. The positive source has been corrected and rerun separately; see [attempt 32](../attempt-32-c16.12-corrected/README.md).
