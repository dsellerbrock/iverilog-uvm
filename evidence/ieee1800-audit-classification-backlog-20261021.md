# IEEE 1800 audit classification backlog — 2026-10-21

Snapshot sent to the audit lead before classification. The lead classified all 13 rows with no new issues; full source rows and the evidence/dedupe audit are preserved below.

## Matrix line 577: §7.10.2.1 / §7.10.2.1

| §7.10.2.1 / §7.10.2.1 | `size()` reports the current element count through empty/nonempty slices and method mutations in both editions | PROBED — LEAD PENDING | [`p07_10_queue_size.sv`](../../../tests/1800_audit/c07/p07_10_queue_size.sv) | [Slurm job 3510](../../../evidence/ieee1800-audit-c07a-20261020/attempt-02-lv-isolate/RESULT.md) | — |

Evidence path: [Slurm job 3510](../../../evidence/ieee1800-audit-c07a-20261020/attempt-02-lv-isolate/RESULT.md)
Dedupe record: YES: named open/closed dedupe files under evidence/ieee1800-audit-c07a-20261020/.

## Matrix line 578: §7.10.2.2 / §7.10.2.2

| §7.10.2.2 / §7.10.2.2 | `insert()` at a valid index and at `size()` inserts at the expected position; negative and out-of-range indices leave the queue unchanged in both editions | PROBED — LEAD PENDING | [`p07_10_queue_size.sv`](../../../tests/1800_audit/c07/p07_10_queue_size.sv) | [Slurm job 3510](../../../evidence/ieee1800-audit-c07a-20261020/attempt-02-lv-isolate/RESULT.md) | — |

Evidence path: [Slurm job 3510](../../../evidence/ieee1800-audit-c07a-20261020/attempt-02-lv-isolate/RESULT.md)
Dedupe record: YES: named open/closed dedupe files under evidence/ieee1800-audit-c07a-20261020/.

## Matrix line 579: §7.10.2.3 / §7.10.2.3

| §7.10.2.3 / §7.10.2.3 | `delete(index)` removes a valid element, an out-of-range index has no effect, and `delete()` empties the queue in both editions | PROBED — LEAD PENDING | [`p07_10_queue_size.sv`](../../../tests/1800_audit/c07/p07_10_queue_size.sv) | [Slurm job 3510](../../../evidence/ieee1800-audit-c07a-20261020/attempt-02-lv-isolate/RESULT.md) | — |

Evidence path: [Slurm job 3510](../../../evidence/ieee1800-audit-c07a-20261020/attempt-02-lv-isolate/RESULT.md)
Dedupe record: YES: named open/closed dedupe files under evidence/ieee1800-audit-c07a-20261020/.

## Matrix line 580: §7.10.2.4 / §7.10.2.4

| §7.10.2.4 / §7.10.2.4 | Nonempty `pop_front()` returns/removes the first item; 4-state empty-pop default is X; 2-state empty-pop result is separately tracked at §7.10.2 | PROBED — LEAD PENDING | [`p07_10_queue_size.sv`](../../../tests/1800_audit/c07/p07_10_queue_size.sv), [`p07_10_pop_default.sv`](../../../tests/1800_audit/c07/p07_10_pop_default.sv) | [Slurm job 3510](../../../evidence/ieee1800-audit-c07a-20261020/attempt-02-lv-isolate/RESULT.md), [job 3511](../../../evidence/ieee1800-audit-c07a-20261020/attempt-03-pop-default/RESULT.md) | — |

Evidence path: [Slurm job 3510](../../../evidence/ieee1800-audit-c07a-20261020/attempt-02-lv-isolate/RESULT.md), [job 3511](../../../evidence/ieee1800-audit-c07a-20261020/attempt-03-pop-default/RESULT.md)
Dedupe record: YES: named open/closed dedupe files under evidence/ieee1800-audit-c07a-20261020/.

## Matrix line 581: §7.10.2.5 / §7.10.2.5

| §7.10.2.5 / §7.10.2.5 | Nonempty `pop_back()` returns/removes the last item; 4-state empty-pop default is X; 2-state empty-pop result is separately tracked at §7.10.2 | PROBED — LEAD PENDING | [`p07_10_queue_size.sv`](../../../tests/1800_audit/c07/p07_10_queue_size.sv), [`p07_10_pop_default.sv`](../../../tests/1800_audit/c07/p07_10_pop_default.sv) | [Slurm job 3510](../../../evidence/ieee1800-audit-c07a-20261020/attempt-02-lv-isolate/RESULT.md), [job 3511](../../../evidence/ieee1800-audit-c07a-20261020/attempt-03-pop-default/RESULT.md) | — |

Evidence path: [Slurm job 3510](../../../evidence/ieee1800-audit-c07a-20261020/attempt-02-lv-isolate/RESULT.md), [job 3511](../../../evidence/ieee1800-audit-c07a-20261020/attempt-03-pop-default/RESULT.md)
Dedupe record: YES: named open/closed dedupe files under evidence/ieee1800-audit-c07a-20261020/.

## Matrix line 582: §7.10.2.6 / §7.10.2.6

| §7.10.2.6 / §7.10.2.6 | `push_front()` adds the expected first element and preserves order in both editions | PROBED — LEAD PENDING | [`p07_10_queue_size.sv`](../../../tests/1800_audit/c07/p07_10_queue_size.sv) | [Slurm job 3510](../../../evidence/ieee1800-audit-c07a-20261020/attempt-02-lv-isolate/RESULT.md) | — |

Evidence path: [Slurm job 3510](../../../evidence/ieee1800-audit-c07a-20261020/attempt-02-lv-isolate/RESULT.md)
Dedupe record: YES: named open/closed dedupe files under evidence/ieee1800-audit-c07a-20261020/.

## Matrix line 583: §7.10.2.7 / §7.10.2.7

| §7.10.2.7 / §7.10.2.7 | `push_back()` adds the expected last element; bounded-queue overflow remains within the declared maximum and is covered at §7.10.5 in both editions | PROBED — LEAD PENDING | [`p07_10_queue_size.sv`](../../../tests/1800_audit/c07/p07_10_queue_size.sv) | [Slurm job 3510](../../../evidence/ieee1800-audit-c07a-20261020/attempt-02-lv-isolate/RESULT.md) | — |

Evidence path: [Slurm job 3510](../../../evidence/ieee1800-audit-c07a-20261020/attempt-02-lv-isolate/RESULT.md)
Dedupe record: YES: named open/closed dedupe files under evidence/ieee1800-audit-c07a-20261020/.

## Matrix line 585: §7.10.4 / §7.10.4

| §7.10.4 / §7.10.4 | Tested standard examples for append, prepend, front/back removal, insertion before/after an index, empty assignment, and queue trimming produced the expected complete queue values in both editions; broader semantics remain unassessed | PROBED — LEAD PENDING | [`p07_10_4_assignment.sv`](../../../tests/1800_audit/c07/p07_10_4_assignment.sv) | [Slurm job 3560](../../../evidence/ieee1800-audit-c07g-20261020/attempt-01-assignment/RESULT.md) | — |

Evidence path: [Slurm job 3560](../../../evidence/ieee1800-audit-c07g-20261020/attempt-01-assignment/RESULT.md)
Dedupe record: No dedupe file found in the linked c07g attempt-01 evidence directory.

## Matrix line 663: §35.5.1.3, §35.5.2 / same

| §35.5.1.3, §35.5.2 / same | Legal pure imported integer functions return values based only on their input arguments in both editions; optimizer elimination and the complete side-effect restrictions were not tested | PROBED — LEAD PENDING | [`dpi_basic_test.sv`](../../../tests/dpi_basic_test.sv), [`dpi_basic_test.c`](../../../tests/dpi_basic_test.c) | [Paired-edition pure-import probe, Slurm job 3564](../../../evidence/ieee1800-audit-c35d-20261020/attempt-01-pure-import/RESULT.md) | — |

Evidence path: [Paired-edition pure-import probe, Slurm job 3564](../../../evidence/ieee1800-audit-c35d-20261020/attempt-01-pure-import/RESULT.md)
Dedupe record: YES: named DEDUPE.md files under evidence/ieee1800-audit-c35c/c35d-20261020/.

## Matrix line 664: §35.5.6.1, Annex H.10.1–H.10.3 / same

| §35.5.6.1, Annex H.10.1–H.10.3 / same | Imported 1-D open-array reads/writes, dynamic 2-D geometry, bounds and increments, and ascending/descending fixed-array declared ranges pass in both editions | PROBED — LEAD PENDING | [`m10_dpi_openarray_test.sv`](../../../tests/m10_dpi_openarray_test.sv), [`m10_dpi_open_array_bounds_test.sv`](../../../tests/m10_dpi_open_array_bounds_test.sv), [`m10_dpi_open_array_layout_range_test.sv`](../../../tests/m10_dpi_open_array_layout_range_test.sv) | [Paired-edition open-array ABI probe, Slurm job 3565](../../../evidence/ieee1800-audit-c35d-20261020/attempt-02-openarray-abi/RESULT.md) | — |

Evidence path: [Paired-edition open-array ABI probe, Slurm job 3565](../../../evidence/ieee1800-audit-c35d-20261020/attempt-02-openarray-abi/RESULT.md)
Dedupe record: YES: named DEDUPE.md files under evidence/ieee1800-audit-c35c/c35d-20261020/.

## Matrix line 666: §35.5.5–§35.5.6 / same

| §35.5.5–§35.5.6 / same | `chandle` return and input formals round-trip a C pointer (`mk_h` → `rd_h` → `fr_h`) in both editions | PROBED — LEAD PENDING | [`m10j_dpi_chandle_abi_test.sv`](../../../tests/m10j_dpi_chandle_abi_test.sv), [`m10j_dpi_chandle_abi_test.c`](../../../tests/m10j_dpi_chandle_abi_test.c) | [Paired-edition DPI ABI probe, Slurm job 3563](../../../evidence/ieee1800-audit-c35c-20261020/attempt-01-chandle-abi/RESULT.md) | — |

Evidence path: [Paired-edition DPI ABI probe, Slurm job 3563](../../../evidence/ieee1800-audit-c35c-20261020/attempt-01-chandle-abi/RESULT.md)
Dedupe record: YES: named DEDUPE.md files under evidence/ieee1800-audit-c35c/c35d-20261020/.

## Matrix line 720: [#446](https://github.com/dsellerbrock/iverilog-uvm/issues/446)

| [#446](https://github.com/dsellerbrock/iverilog-uvm/issues/446) | §§16.13.1–16.13.3 | Finite ranged antecedent handoff, distinct overlapping obligations and a three-clock chain pass in the tested cases; endpoint synchronization via `matched`, local-variable capture and termination remain untested here | PROBED — LEAD PENDING | [`sv_assert_multiclock_variable_antecedent.v`](../../../evidence/ieee1800-audit-c16b-20261020/attempt-01-variable-multiclock/input/ivltests/sv_assert_multiclock_variable_antecedent.v), [`sv_assert_multiclock_multiplicity.v`](../../../evidence/ieee1800-audit-c16c-20261020/attempt-01-multiplicity/input/sv_assert_multiclock_multiplicity.v), [`sv_assert_multiclock_chain3.v`](../../../evidence/ieee1800-audit-c16d-20261020/attempt-01-three-clock-chain/input/sv_assert_multiclock_chain3.v) | [Job 3581](../../../evidence/ieee1800-audit-c16b-20261020/attempt-01-variable-multiclock/README.md), [job 3582](../../../evidence/ieee1800-audit-c16c-20261020/attempt-01-multiplicity/README.md), [job 3583](../../../evidence/ieee1800-audit-c16d-20261020/attempt-01-three-clock-chain/README.md) |

Evidence path: [Job 3581](../../../evidence/ieee1800-audit-c16b-20261020/attempt-01-variable-multiclock/README.md), [job 3582](../../../evidence/ieee1800-audit-c16c-20261020/attempt-01-multiplicity/README.md), [job 3583](../../../evidence/ieee1800-audit-c16d-20261020/attempt-01-three-clock-chain/README.md)
Dedupe record: Open-and-closed multiclock search is recorded in the linked c16b/c16c READMEs; no separate dedupe-named file.

## Matrix line 822: [#834](https://github.com/dsellerbrock/iverilog-uvm/issues/834)

| [#834](https://github.com/dsellerbrock/iverilog-uvm/issues/834) | §19.5.1 | Explicit full and bounded 256-bit covergroup value ranges are rejected in both editions | PROBED — LEAD PENDING | [`sv_covergroup_wide_range_bins.v`](../../../ivtest/ivltests/sv_covergroup_wide_range_bins.v), [`sv_covergroup_wide_range_bins_2023.v`](../../../ivtest/ivltests/sv_covergroup_wide_range_bins_2023.v) | [Current-main baseline, Slurm job 3572](../../../evidence/issue834-wide-cover-bins-20261020/baseline-current-main/README.md), [root-cause and open/closed dedupe](../../../evidence/issue834-wide-cover-bins-20261020/ROOT_CAUSE.md) |

Evidence path: [Current-main baseline, Slurm job 3572](../../../evidence/issue834-wide-cover-bins-20261020/baseline-current-main/README.md), [root-cause and open/closed dedupe](../../../evidence/issue834-wide-cover-bins-20261020/ROOT_CAUSE.md)
Dedupe record: Open/closed search is recorded in ROOT_CAUSE.md in the sibling issue834 worktree; that evidence path does not resolve in this checkout.
