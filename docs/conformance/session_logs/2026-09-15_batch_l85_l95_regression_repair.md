# L85–L95 broad-gate regression repair

The first frozen candidate `5898ea050` failed the integrated gate: 14 legacy regressions and one negative-suite expectation. The raw candidate hashes and logs remain in `evidence/batch-20260914-after-l84/qualification/`; no broad qualification is claimed for it. The sequential runner stopped there, before the other six gates.

The negative test `sva_multiclock_variable_antecedent` described a legal finite Boolean repetition that L91 now implements. Its rejection expectation is superseded. The case moved into ivtest as `sv_assert_multiclock_variable_antecedent`, where actual clocks produce two child obligations and require one parent failure. Both legacy and JSON harnesses pass in 2012, 2017 and 2023 modes. This preserves the old default generation-mode check and adds edition-specific runtime evidence; it does not weaken an illegal-input diagnostic.

Packed-select compatibility and constrained-randc cycle failures remain under independent repair. Their corrected source and validation will be recorded before restarting the complete qualification.

The packed-select regression came from applying `%cast2` to every internally BOOL-tagged select in the VVP target. Legacy Verilog parameters can carry that tag while their out-of-range selection must retain X bits. The correction removes the generic target conversion and inserts an explicit cast only around an exact two-state enum property selection, after the four-state select operation. All13 legacy failures pass; the L90 enum suite passes10 cases in each harness. Source and installed hashes are in the accompanying repair JSON.
