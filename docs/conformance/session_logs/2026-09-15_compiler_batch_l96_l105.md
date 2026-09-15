# L96–L105 compiler batch

Ten independently scoped compiler fixes are integrated at semantic revision `366ef2bf1`. The [qualification record](2026-09-15_compiler_batch_l96_l105_qualification.json) owns the exact candidate, gate results and fingerprints. This is local qualification of the recorded subsets, not full IEEE/UVM/application conformance. The whole UVM suite uses its existing 2012 mode; focused regressions are paired for2017 and2023.

| Fix | Evidence | Revision |
| --- | --- | --- |
| L96 | [constant function formal legality](2026-09-15_constant_function_formal_legality.md) | `c681f81a5` |
| L97 | [nested finite grouped repetition](2026-09-15_nested_finite_grouped_repetition.md) | `a49ee5d3e` |
| L98 | [generated constant function legality](2026-09-15_generated_constant_function_legality.md) | `fc296ee07` |
| L99 | [fixed string array methods](2026-09-15_fixed_string_array_methods.md) | `34b1cc24c` |
| L100 | [finite multiclock consequences](2026-09-15_finite_multiclock_consequences.md) | `450c63f00` |
| L101 | [constant array character increment](2026-09-15_constant_array_character_increment.md) | `7ef17f630` |
| L102 | [plain multiclock consequences](2026-09-15_plain_multiclock_consequences.md) | `0efbf81c5` |
| L103 | [plain multiclock ranged prefix](2026-09-15_plain_multiclock_ranged_prefix.md) | `eb5eb6ebb` |
| L104 | [constant mixed equality](2026-09-15_constant_mixed_equality.md) | `c26384d29` |
| L105 | [nonlocal constant function values](2026-09-15_nonlocal_constant_function_values.md) | `366ef2bf1` |

The first integrated candidate failed only because five negative golds still expected earlier diagnostics. The [failed-gate correction](2026-09-15_l96_l105_first_gate_correction.md) preserves those results and the focused replay. No compiler source or failure baseline was weakened to obtain the retry.

The next PR against main also preserves L75–L95: their earlier stacked PR merges did not propagate those later commits into main. Those prior batches remain separately identified, not counted as newly implemented in this batch.
