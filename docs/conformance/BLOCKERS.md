# Blockers registry (Level 3 — operational backlog)

### OT-SPI-CLASS-EVENT-TRIGGERED — per-instance event state in expressions

- **State:** Merged in [PR340](https://github.com/dsellerbrock/iverilog-uvm/pull/340) at `909e3f314` after exact-head Ubuntu 22.04 success. The [candidate evidence](session_logs/2026-09-23_opentitan_class_event_triggered_focus.json) shows all three class-event errors removed from the pinned SPI compile. No SPI Device DV qualification is claimed.
- **Requirement:** IEEE 1800-2017/2023 §15.5.3 keeps an event's triggered state true for the firing time step and lets `wait (obj.ev.triggered)` handle either same-time trigger order. Different class instances must remain independent.
- **Cause and boundary:** Class-event reads fell into ordinary class-property lookup before per-object event lowering; `wait` also entered an unrelated direct-event fast path. The candidate reuses per-object VVP event opcodes and passes paired positive, negative, boundary, and instance-isolation checks. Explicit `triggered()` calls remain separate debt; the pinned SPI compile still fails on other mechanisms.

### OT-AON-EVENT-TRIGGERED-SENSITIVITY — named-event property changes

- **State:** Integrated at `0a902ee9f`; the [revision-scoped replay](session_logs/2026-09-23_inside_array_named_event_integration.json) records paired static and automatic checks and a zero-error released AON compile. Its bounded smoke produced no UVM verdict; the later [mixed-VIF repair checkpoint](session_logs/2026-09-23_opentitan_spi_aon_postfix.json) records one passing unchanged AON smoke.
- **Requirement:** IEEE 1800-2017/2023 §15.5.3 keeps `e.triggered` true through the firing time step. `@(e.triggered)` observes its value changes, including the reset at the next real time advance, with independent state per automatic activation.
- **Boundary:** The earlier timeout is superseded for the observed smoke sequence by the mixed-VIF event-wait repair below. Full AON DV remains unqualified.

### OT-AON-MIXED-VIF-EVENT-WAIT — edge-qualified virtual-interface event list

- **State:** Integrated at `07d8ba6df`; [paired focus and neighboring tests plus the unchanged AON smoke](session_logs/2026-09-23_opentitan_spi_aon_postfix.json) pass. This covers the observed smoke only.
- **Requirement:** IEEE 1800-2017/2023 §§9.4.2 and 25.9 wake an event-OR control on the first selected virtual-interface member edge, respecting each leaf's edge qualifier and cancelling sibling waits.
- **Cause and boundary:** The target lowered mixed negedge/anyedge VIF lists to static events even though single-VIF waits were dynamic. A new per-leaf edge-mode wait handles the tested reset and pin branches, same-slot wake, rearm, rebinding, cancellation, and null-VIF rejection. Full event-control and AON DV qualification remain open.

### OT-SPI-ASSOC-FIND-INDEX — keyed associative locator

- **State:** Merged in [PR341](https://github.com/dsellerbrock/iverilog-uvm/pull/341) at `7943dffd1` after exact-head Ubuntu 24.04 success. The [candidate evidence](session_logs/2026-09-23_opentitan_assoc_find_index_multi_object_focus.json) records that the released SPI Device compile advanced to a separate queue-randomize error, which is now resolved; the UCRT64 checkout failed certificate trust before compiler execution.
- **Requirement:** IEEE 1800-2017/2023 §7.12.1 `find_index()` returns matching associative keys with their declared type, rather than ordinal positions.
- **Boundary:** Integral and string keys are tested; wildcard/object keys and other associative locators remain loud unsupported cases. The separate queue `std::randomize` rejection is cleared; the pinned SPI Device compile still reports later vector-context diagnostics.

### OT-CLASS-EVENT-MULTI-OBJECT-LIST — event controls lose object identity

- **State:** Merged in [PR341](https://github.com/dsellerbrock/iverilog-uvm/pull/341) at `7943dffd1` after exact-head Ubuntu 24.04 success. The [paired RED reducer](../../evidence/ot-class-event-multi-object-list-triage-20260923/README.md) now passes at runtime in both editions; see the shared [candidate evidence](session_logs/2026-09-23_opentitan_assoc_find_index_multi_object_focus.json).
- **Requirement:** IEEE 1800-2017/2023 §15.5 `@(a.ev or b.ev)` wakes on either selected class object's event. The candidate gives each leaf its existing per-object waiter and joins them for a one-shot event control.
- **Boundary:** Explicit `triggered()` call syntax remains DD-052; no full named-event or OpenTitan DV qualification is claimed.

### OT-SPI-STD-RANDOMIZE-QUEUE — constrained scope queue argument

- **State:** Focused implementation integrated at `512d53539` following compiler commit `c44dc1dd4`; the paired scope tests pass. The former [RED reducer](../../evidence/ot-spi-std-randomize-queue-20260923/README.md) now passes with `-g2017`. The pinned SPI Device compile no longer reports this queue-randomize rejection but has eight later vector-context diagnostics; no application compile or DV pass is claimed.
- **Requirement:** IEEE 1800-2017/2023 §18.12 scope `std::randomize` accepts its queue argument with an inline size constraint and preserves the queue on an unsatisfiable solve.
- **Boundary:** Support is limited to one-dimensional local integral queues whose length is exactly constrained, through 65536 elements. A declared queue maximum is honored; nonexact or over-limit requests are diagnosed and rolled back. Other argument forms and arbitrary queue sizing are not supported. This bounded implementation does not qualify the full §18.12 clause.
- **Evidence:** [Revision-scoped focus](session_logs/2026-09-23_scope_queue_randomize_focus.json).

### OT-SPI-INSIDE-CONST-ARRAY — unpacked parameter array in an `inside` set

- **State:** The ordinary-expression path was implemented at `88f0e9044`; [earlier paired evidence](session_logs/2026-09-23_inside_array_named_event_integration.json) preserves that scope. The separate constraint-context path is integrated at `b7551af50`; the [postfix record](session_logs/2026-09-23_opentitan_spi_aon_postfix.json) shows the pinned SPI Device fileset now compiles without the kind-26 error. Its configured smoke still fails at an independent solver enumeration limit.
- **Requirement:** IEEE 1800-2017/2023 §11.4.13 recursively traverses an unpacked array in an `inside` set to its singular elements and applies asymmetric wildcard equality to integral comparisons. The independent queue-concatenation form remains tracked under [OT-SPI-QUEUE-ARRAY-CONCAT](#ot-spi-queue-array-concat).

### OT-SPI-QUEUE-ARRAY-CONCAT — unpacked array concatenation assigned to a queue

- **State:** Integrated at `2e648c7ec`; the [paired focus, neighbor, and pinned compile record](session_logs/2026-09-23_opentitan_spi_aon_postfix.json) shows both released SPI Device queue-concatenation sites clear. The [original two-form reducer and diagnosis](../../evidence/opentitan-spi-device-array-pattern-vector-20260923/README.md) remains historical.
- **Requirement:** IEEE 1800-2017/2023 §10.10 permits an unpacked array concatenation in an assignment-like context; queue conversion must preserve element order and length. The pinned fileset compiles, but DV does not pass.

### OT-SPI-JEDEC-SAMPLING-LIMIT — configured flash-mode smoke solver ceiling

- **State:** Open after the pinned SPI Device fileset reaches compile exit 0. The [configured smoke and raw log](session_logs/2026-09-23_opentitan_spi_aon_postfix.json) show `ral.jedec_id.randomize()` failing at the complete-joint-solution enumeration limit. VVP process exit 0 follows UVM_FATAL and is not a test pass. The attempted abstract base sequence is not an application defect.
- **Boundary:** This is a solver runtime failure in one unchanged flash-mode smoke. The compile still reports an ignored constraint item and dropped coverage crosses, so neither compile exit 0 nor this smoke establishes SPI Device DV qualification.

### CALIPTRA-L0-DOE-STATUS-SVA — scan test fails a reset-window status assertion

- **State:** Open on the pinned Caliptra v2.1.2 / Adams Bridge v2.0.3 Verilator L0 replay with the selected KV diagnostic overlay. The [exact-toolchain 52-case baseline](../../evidence/caliptra-exact-l0-20260923/README.md) passes 49 cases; two firmware build failures have focused-tested, test-specific overlays, while `smoke_test_doe_scan` still emits one SVA error despite exit 0 and a pass banner.
- **Evidence:** The [reset-window differential and fresh pinned v5.052 DOE replay](../../evidence/caliptra-doe-verilator-midwindow-20260923/assessment.md) preserve the assertion. The [follow-on source diagnosis and restored-binary recheck](session_logs/2026-09-23_caliptra_doe_verilator_defuture_blocker.json) show that a between-clock reset leaves both a defutured implication attempt and a longer NFA obligation pending. Clearing only NFA state fixes the longer reducer but leaves the direct implication failing; no partial patch was retained.
- **Boundary:** This is read-only Verilator differential evidence, not an authorized Verilator implementation lane. The intact DOE assertion remains failed and full Caliptra DV remains unqualified; prioritize Icarus compiler and runtime blockers against the pinned releases.

### OT-SPI-DEVICE-PACKAGE-PARAM-FOREACH — lexical package array bounds

- **State:** Merged in [PR339](https://github.com/dsellerbrock/iverilog-uvm/pull/339) after Ubuntu 24.04 exact-head CI passed; the [follow-on record](session_logs/2026-09-23_spi_adc_pr339_repair_focus.json) covers paired focused tests and the pinned compile. Full SPI Device DV remains open.
- **Requirement:** IEEE 1800-2017 §18.5.8.1 and the paired 2023 `foreach` mode use the actual constant package array when it is referenced from a class method.
- **Cause and boundary:** The bound resolver skipped lexical package parameters. It now finds the array before reporting a missing target; missing and scalar targets still fail. No general package-parameter or coverage qualification is claimed.

### OT-SPI-DEVICE-STRUCT-QUEUE-PARENLESS-SIZE — packed-struct queue method lookup

- **State:** Merged in [PR339](https://github.com/dsellerbrock/iverilog-uvm/pull/339) after Ubuntu 24.04 exact-head CI passed; [paired regression evidence](session_logs/2026-09-23_spi_adc_pr339_repair_focus.json) and the pinned SPI Device compile show the `.size` errors removed. Full DV remains open.
- **Requirement:** IEEE 1800-2017/2023 §7.10.2.1 permits `q.size` as well as `q.size()` for an ordinary queue, including a queue of packed structs.
- **Cause and boundary:** The parenthesis-free path treated `size` as a packed-struct element member before queue dispatch. It now selects the queue method; a missing member on a genuine packed struct still fails.

### OT-ADC-DIRECT-CAST-WIDTH — unbased fill loses cast width in constraints

- **State:** Merged in [PR339](https://github.com/dsellerbrock/iverilog-uvm/pull/339) after Ubuntu 24.04 exact-head CI passed; the [paired runtime and negative evidence](session_logs/2026-09-23_spi_adc_pr339_repair_focus.json) passes. Indexed ADC inner array sizing still blocks the pinned smoke.
- **Requirement:** IEEE 1800-2017/2023 §§5.7.1 and 6.24.1 fill the destination width of a direct typed cast before its value participates in a constraint.
- **Cause and boundary:** Constraint IR encoded `'1` as a one-bit constant before knowing the cast width. The direct fill now has the cast width; sized `1'b1` and two-state X/Z conversion remain distinct. Four-state X/Z constraint casts and fills wider than the current 64-bit IR are explicit unsupported boundaries, not silently solved values.

### OT-PWRMGR-CASE-EXIT-STACK-BALANCE — case body exits bypassed selector cleanup

- **State:** Merged in [PR336](https://github.com/dsellerbrock/iverilog-uvm/pull/336) at `6ee647ca7` after a completed exact-head Ubuntu 24.04 CI success. Full release DV qualification remains open.
- **Requirement:** IEEE 1800-2017/2023 §§9.4, 12.5, and 12.8 preserve procedural `case` and loop exit behavior without leaving a VM selector operand behind.
- **Cause and closure:** Plain, unique, and real-selector codegen popped only at the common case exit; `break`, `continue`, `return`, and `disable` bypassed it. The selector now pops after dispatch and before each body. [Paired-edition and pinned pwrmgr evidence](session_logs/2026-09-23_pwrmgr_case_exit_stack_balance.json) records the focused checks and application replay. Other pwrmgr compile warnings and full OpenTitan DV qualification remain open.

### SV-MACRO-MATCHED-BRACKET-ACTUALS — square-bracket macro actuals split at comma

- **State:** Merged in [PR335](https://github.com/dsellerbrock/iverilog-uvm/pull/335); Ubuntu 24.04 exact-head CI passed after merge.
- **Requirement:** IEEE 1800-2017/2023 §22.5.1 protects separators inside matched `()`, `[]`, and `{}` pairs. Mismatched pairs must not close another delimiter's nesting.
- **Cause and closure:** The scanner counted only `()` and `{}` with one depth integer. A typed delimiter stack now handles matched `[]` and rejects mismatches while preserving strings, comments, and PR334's casted-literal handling. The [paired baseline](../../evidence/macro-bracket-assessment-20260923/README.md) and [integrated checks](session_logs/2026-09-23_vpi_macro_integrated_focus.json) bound this correction; 2023 triple quotes remain separate.

### VPI-LEGACY-VARIABLE-BIT-FORCE-CB-REGISTRATION — bit-select callbacks registered illegally

- **State:** Merged in [PR335](https://github.com/dsellerbrock/iverilog-uvm/pull/335); Ubuntu 24.04 exact-head CI passed after merge.
- **Requirement:** IEEE 1800-2017/2023 §38.36.1 disallows `cbForce` and `cbRelease` registration on variable bit-selects while allowing the supported whole-variable and net-bit forms.
- **Cause and closure:** The legacy `vpiRegBit` and `vpiNetBit` handles shared one registration path. Removing `vpiRegBit` from that path yields a diagnostic and null registration; [paired baseline and integrated VPI checks](session_logs/2026-09-23_vpi_macro_integrated_focus.json) cover the boundary. Callback statement-object identity is a separate open defect.

### CALIPTRA-SVA-LONG-SEQUENCE-REGISTER-COLLISION — generated SVA names collide at step 1000

- **State:** Merged in [PR335](https://github.com/dsellerbrock/iverilog-uvm/pull/335); the focused executable checks and integrated pinned-filelist compile passed locally. Ubuntu 24.04 exact-head CI passed after merge.
- **Requirement:** IEEE 1800-2017/2023 §16.7 permits finite sequence concatenation without a 999-step naming limit. Each sampled check and action must remain observable; compilation alone is insufficient.
- **Cause:** `pform_make_assertion` reserved `b999` for antecedent capture and reused `b999` for consequent step index 999. The [paired baseline and pinned Caliptra PM failure](../../evidence/caliptra-pm-formal-elab-triage-20260923/result.json) reproduce the collision.
- **Evidence:** The [focused record](session_logs/2026-09-23_caliptra_long_sequence_register_focus.json) links executable 999/1000/1001-step 2017/2023 tests and local gates. On the [locally integrated PR334 tree](session_logs/2026-09-23_caliptra_pm_integrated_compile.json), the clean pinned PM formal filelist compiles without diagnostics in both editions. This is compile-only evidence; full Caliptra DV and formal proof remain open.

### OT-ADC-CASTED-UNBASED-INLINE-MACRO-ARG — cast splits a constraint macro actual

- **State:** Merged in [PR334](https://github.com/dsellerbrock/iverilog-uvm/pull/334) after local checks and Ubuntu 24.04 exact-head CI passed; based on the clean pinned Earlgrey-PROD-M6 `adc_ctrl_sim` release target.
- **Requirement:** IEEE 1800-2017/2023 §§22.5.1, 6.24.1, and 5.7.1 require cast delimiters and unbased unsized literals inside a macro actual to retain their nesting so an inner comma or right parenthesis does not end the actual.
- **Cause and evidence:** The first ADC smoke compile diagnostic follows `adc_value_t'('1)` inside `DV_CHECK_RANDOMIZE_WITH_FATAL`; `ivlpp/lexor.lex` consumes the three-character `'('` sequence as one quoted-item token, leaving the inner `)` to end the macro argument. [Pinned target and reducer record](session_logs/2026-09-23_opentitan_adc_macro_arg_baseline.json) distinguishes the failing casted macro from ordinary-literal macro and procedural-cast controls.
- **Closure:** The [candidate and local tests](session_logs/2026-09-23_opentitan_adc_macro_arg_focus.json) preserve cast parentheses and assignment-pattern braces and pass the selected regression gates. The pinned ADC target now compiles but ignores a filter-size constraint, so this is semantic DEBT, not ADC DV success. The separate direct nonmacro cast-width runtime mismatch also remains.

### OT-ADC-NESTED-DYNAMIC-ARRAY-RESIZE — ADC `filter_cfg[][]` randomization

- **State:** The typed outer-resize slice is locally integrated at `0bf19490c`; indexed inner `.size` lowering remains open, so pinned ADC smoke still fails at time 0. See the [focused candidate record](session_logs/2026-09-23_parallel_compiler_followon_focus.json).
- **Evidence:** The [paired reducer and pinned-source assessment](../../evidence/opentitan-adc-class-resize-triage-20260923/assessment.md) shows that `filter_cfg` is a nested dynamic array of packed structs, not class handles. VVP's `class-handle collection` error applies an overbroad guard to this type. The outer size reaches solver IR, but typed resize/write-back is missing; the indexed inner `.size` constraint is separately dropped during elaboration ([DD-047](DISCOVERED_DEBT.md)).
- **Closure:** Finish indexed inner resize and nested size/element constraints with correct retention and rollback in both IEEE editions; keep actual class-handle growth semantics distinct. Rerun pinned ADC DV only after these semantics pass focused positive, negative, and boundary tests. No ADC DV pass is established.

### OT-SPI-DEVICE-CONSTRAINT-FOREACH-PATH — sparse caller-owned command keys

- **State:** Locally integrated at `c64b1791f`; [paired focused evidence](session_logs/2026-09-23_parallel_compiler_followon_focus.json) covers the released SPI shape. Full SPI Device DV and broad compiler qualification remain open.
- **Requirement:** IEEE 1800-2017 §18.5.8.1 and 2023 §18.5.7.1 iterate actual associative-array keys in a constraint `foreach` over a caller-owned hierarchical source.
- **Boundary:** The tested implementation supports unsigned integral keys up to 64 bits; invalid nonarray sources fail compilation. This does not establish general associative-array constraint coverage.

### VPI-FORCE-RELEASE-CALLBACK-STMT-OBJECT — callback origin identity

- **State:** The HDL statement-object slice and VPI API-origin callback repair merged in [PR339](https://github.com/dsellerbrock/iverilog-uvm/pull/339) after Ubuntu 24.04 exact-head CI passed. The [follow-on local gates](session_logs/2026-09-23_spi_adc_pr339_repair_focus.json) pass; broad VPI qualification remains open.
- **Requirement:** IEEE 1800-2017/2023 §38.36.1 callback `obj` identifies the force or release statement, including a shared identity for concatenated LHS targets; registration still uses the affected signal.
- **Boundary:** Compiled HDL statements expose type and source location. A VPI `put_value` force/release has no HDL source statement; its callback retains the registered target handle as the established API extension behavior. Other statement-handle relationships remain unqualified.

### CALIPTRA-LATE-DEFAULT-CLOCKING — assertions before their module default clock

- **State:** Merged in [PR334](https://github.com/dsellerbrock/iverilog-uvm/pull/334) after local checks and Ubuntu 24.04 exact-head CI passed; source/test commit `342226068` was based on `origin/main` `42f324c90`.
- **Requirement:** IEEE 1800-2017/2023 §§14.12 and 16.14.6 scope a default clocking to its containing module and permit it to supply an otherwise unclocked concurrent assertion. The declaration's later textual position must not turn earlier module assertions into missing-clock errors.
- **Cause and evidence:** The pinned clean Caliptra v2.1.2 `fv_ecc_dsa_sequencer.sv` has five assertions at lines 91–95 before its default clocking at line 97. [The revision-scoped baseline and candidate record](session_logs/2026-09-23_caliptra_late_default_clocking_focus.json) captures the five false missing-clock errors and their removal. `pform_make_assertion` parked the earlier assertions, then `pform_endmodule` popped their module before the pending-procedural flush rejected them.
- **Closure:** The fix retries parked assertions while the validated module default clock and generate scope remain in place; paired execution and rejection boundaries are tested. The pristine pinned formal file still fails on an upstream `DSA_NOP` name mismatch; a [test-specific disposable-copy overlay](session_logs/2026-09-23_caliptra_ecc_nop_overlay.json) compiles it without that mismatch. No formal proof or Caliptra DV qualification follows.

### CALIPTRA-NAMED-SEQUENCE-PARAM-CONSEQUENT — named antecedent captured as a function

- **State:** Merged in [PR333](https://github.com/dsellerbrock/iverilog-uvm/pull/333) at `bdf461a87` after local gates and completed exact-head Ubuntu 24.04 CI success. Full Caliptra DV/formal qualification remains open.
- **Requirement:** IEEE 1800-2017/2023 §§16.8 and 16.12.7 permit a named sequence in an implication antecedent and require the instance's symbolic consequent repetition to execute.
- **Evidence:** The [revision-scoped record](session_logs/2026-09-23_caliptra_named_sequence_antecedent.json) preserves the paired baseline failure, executable tests, and clean pinned ECC formal bind compile. The helper in `pform.cc` ran before named-sequence splicing; declared references now defer to its post-splice offer.
- **Closure:** Resolve the declared sequence before Boolean lowering, verify pass/fail/vacuity/disable and W=0/positive bounds at runtime in both modes, preserve an unknown-sequence diagnostic, and recompile the pinned full ECC formal bind without dropped properties. Full Caliptra DV/formal qualification stays separate.

### SVA-LITERAL-OVERLAP-FAILURE-COUNT — fixed-linear same-edge verdicts

- **State:** The fixed non-negated linear-checker subset merged in [PR332](https://github.com/dsellerbrock/iverilog-uvm/pull/332) at `5dacd0dec` after local gates and completed exact-head Ubuntu 24.04 CI success. See the [revision-scoped baseline and qualification record](session_logs/2026-09-23_sva_literal_overlap_attempt_identity.json).
- **Requirement:** IEEE 1800-2017/2023 §§16.12.7 and 16.14.1 require a separate verdict and failure action for each distinct antecedent match; §39.4.2 requires callback metadata to retain the actual attempt start.
- **Cause and correction:** A one-bit failure flag collapsed simultaneous fixed-offset failures, and X/Z checks did not become definite nonmatches. The legacy linear checker now counts distinct failed tokens and carries each start time through the VPI report. The first NFA-only attempt was ineffective and reverted.
- **Remaining boundary:** Window, unbounded, negated, and other checker families retain their earlier VPI metadata path. Full SVA and formal qualification remain open.

### CALIPTRA-PARAM-CONSEQUENT-REPEAT — symbolic repetition in an SVA consequent

- **State:** Merged in [PR330](https://github.com/dsellerbrock/iverilog-uvm/pull/330) after exact-head CI success. The [local candidate](session_logs/2026-09-23_caliptra_param_consequent_repeat_focus.json) executes the focused shape in both editions, removes the two dropped-property diagnostics from the clean Caliptra v2.1.2 formal file, and passed its required local gates. Full Caliptra DV/formal qualification remains separate.
- **Requirement:** IEEE 1800-2017/2023 §§16.9.2 and 16.12.7 require the consecutive repetition and implication to use each instance's bound with correct match, failure, vacuity, and disable behavior. Confirm exact edition wording before patching.
- **Cause and evidence:** `pform.cc` retains the bound as `rep_kind 4`, but `sva_parameter_repeat_try_assertion_` accepts only an antecedent repetition and the NFA refuses this sentinel. The [paired pinned-source and minimal-reducer baseline](session_logs/2026-09-23_caliptra_param_consequent_repeat_baseline.json) shows the property drop; a literal-bound control compiles. A separate standalone bind-target error is not the SVA defect.
- **Closure:** Reuse instance-sized bound and assertion dispatch machinery, prove executable W=2/W=3 timing, failure, overlap, vacuity, disable, and zero/invalid-bound behavior in both editions, then recompile the pinned source and run required gates. Never substitute the declaration default or count compilation alone as implementation.

### CALIPTRA-REJ-BOUNDED-RUNTIME — scoreboard/zeroize testbench race

- **State:** A minimal downstream testbench patch is focused-tested in an isolated copy. The pristine Caliptra v2.1.2 / Adams Bridge v2.0.3 release remains unmodified and fails this unit test.
- **Cause:** Independent `posedge clk_tb` processes update and inspect the same blocking counter. IEEE 1800-2017/2023 §4.7 does not order their Active-region execution; the checker can schedule zeroize a cycle late.
- **Evidence:** [Race-fix record](session_logs/2026-09-23_caliptra_rej_bounded_race_fix.json) and [patch/reducer](repros/caliptra_rej_bounded/README.md). The correction keeps queue underflow and output checks active.
- **Open work:** [Upstream PR 303](https://github.com/chipsalliance/adams-bridge/pull/303) is open. Use an explicit overlay in application replays until an adopted release contains the correction; keep pristine and patched results separate. Full Caliptra DV has not passed.

### COMMERCIAL-SIM-UNSAFE-FLAG — opt-in packed bit/logic container conversion

- **State:** The compatibility flag is implemented at `9111127532c71fc4eeaf1bab68685ade3c61296f` in [PR326](https://github.com/dsellerbrock/iverilog-uvm/pull/326); strict IEEE type checking remains the default. Focused checks and [post-merge local gates](session_logs/2026-09-23_pr326_postmerge_qualification.json) pass on the documented equivalent compiler/test tree; GitHub CI was pending at observation.
- **Requirement:** IEEE 1800-2017/2023 §7.6 array element type equivalence remains strict by default. `-gcommercial-unsafe` is an explicitly nonstandard compatibility extension limited to equal-width, equal-signedness packed `bit`/`logic` value conversion in whole queue/dynamic-array assignment and native task/function value copies.
- **Evidence:** [Revision-scoped record](session_logs/2026-09-23_commercial_unsafe_flag.json) records the focused tests and exact OpenTitan SPI compile. Enabling the flag clears its strict type errors but leaves nonblocking property assignment codegen errors. OpenTitan DV has not passed.
- **Open work:** Resolve the remaining nonblocking property assignment lowering errors before claiming SPI compile or DV success. Do not count flag acceptance as IEEE qualification or VCS equivalence.

### TASK-CODEGEN-ERROR-DROPPED — task-body target errors do not fail compilation

- **State:** CLOSED in [PR328](https://github.com/dsellerbrock/iverilog-uvm/pull/328) at `4f66ed666` after local gates and one completed current-head CI job passed. Later CI jobs remain separately observable. On base `3be18e4b6`, a class task with an unsupported target form reported a `vvp.tgt error` but returned compile status 0 and emitted an invalid image.
- **Cause:** `draw_task_definition` returns the `show_statement` error count, but `draw_scope` discards it in `tgt-vvp/vvp_scope.c`; the adjacent function path adds its count to `vvp_errors`.
- **Evidence:** Local reducer and base compile logs in `evidence/opentitan-codegen-assessment-20260923/`; [candidate local gates](session_logs/2026-09-23_opentitan_nba_codegen_focus.json) pass. The current SPI compile has zero target errors, though separate semantic degradation remains.
- **Closure:** Propagate task-body errors without suppressing diagnostics; permanently test a still-unsupported task-body form with nonzero compile status and a valid neighboring task. This does not implement the selected-bit NBA.

### VIF-NBA-SELECTED-BIT — dynamic property bit-select NBA is unsupported

- **State:** CLOSED in [PR328](https://github.com/dsellerbrock/iverilog-uvm/pull/328) at `4f66ed666` after local gates and one completed current-head CI job passed. Later CI jobs remain separately observable. On base `3be18e4b6`, five SPI Host driver assignments to `vif.sio[i]` emitted unsupported-form errors.
- **Requirement:** IEEE 1800-2017 and 1800-2023 §10.4.2 evaluate variable LHS components (including index and virtual-interface reference) and RHS when the NBA executes, with the update deferred to the NBA region.
- **Evidence:** Reduced base source and compile log in `evidence/opentitan-codegen-assessment-20260923/`; [candidate record](session_logs/2026-09-23_opentitan_nba_codegen_focus.json) includes paired-edition tests and all required local gates. Four inline-constraint index warnings and a dropped queue-pop expression still prevent an SPI semantic compile pass.
- **Closure:** Capture receiver, selector, and four-state RHS at enqueue; update only the selected packed bit in the NBA region; prove old value before NBA and captured value afterward in both editions, plus boundaries and focused neighboring regressions. Do not claim SPI DV success from codegen alone.

### OT-SPI-QUEUE-POP-DROPPED — parenthesis-free class-property queue pop is dropped

- **State:** IN_PROGRESS, locally focus-tested through `3b6d1986f` on a branch stacked after PR328. The pinned OpenTitan SPI Host source calls `cmd_check(item.data.pop_front)`; the previous compiler warned that the expression was dropped, returned success, and lost the queue mutation and byte value.
- **Requirement:** IEEE 1800-2017/2023 §§5.13 and 7.10.2.4 permit omitting empty parentheses on a direct zero-argument built-in method call; `pop_front` removes and returns the first element. The 2023 §13.4.1 parentheses rule for dereferencing a function return does not apply to this direct value use.
- **Evidence:** [Paired focused and pinned SPI compile record](session_logs/2026-09-23_opentitan_queue_pop_focus.json). The prior `evidence/opentitan-queue-pop-20260923/repro.sv` fails in both editions without parentheses; its `-DPARENS_CONTROL` form passes. The root cause is `PEIdent::elaborate_expr_class_field_` in `elab_expr.cc`.
- **Closure:** The typed `pop_front`/`pop_back` result, single queue mutation, empty-queue boundary, invalid arity, and neighboring checks pass locally. [Boundary follow-up](session_logs/2026-09-23_queue_pop_assoc_boundary.json) rejects these methods on associative arrays in expression context while preserving an associative-array element whose type is a queue. The [statement-method candidate](session_logs/2026-09-23_assoc_queue_statement_methods_focus.json) now rejects five queue-only methods on associative receivers in the shared dispatch; broad gates and CI remain open. Full SPI DV is separate.

This file is a **backlog**, not an authorization to implement. Per
`AGENTS.md`, only `.ai/ACTIVE_WORK.yaml` (status: `in_progress`, naming a
blocker ID from this file) authorizes implementation work. Reading a row
here as "next" and starting to code is exactly the failure mode this file
exists to prevent.

This is a **seed set**, not a migrated copy of `iverilog_uvm_blocker_audit.md`
/ `blocker_inventory.json` (134 grouped entries). Those documents remain the
fuller inventory; entries here were promoted because they have concrete
source/recorded evidence and a plausible closure test. Promote additional
rows from the audit into this format as they are picked up — do not bulk
import.

## Status vocabulary

| Status | Meaning |
|---|---|
| `OPEN` | Identified, not yet reproduced on current HEAD. |
| `REPRODUCED` | A current-HEAD failing reducer exists. |
| `IN_PROGRESS` | An `.ai/ACTIVE_WORK.yaml` ticket currently targets this ID. |
| `BLOCKED` | Requires architecture change or a decision beyond scope lock; see its entry for what's blocking. |
| `CLOSED` | Fixed, tested, and documented per the manifesto's Definition of Done. Record the closing PR. |
| `WONTFIX` | Deliberately out of scope (e.g. illegal-source rejection working as intended); record why. |

## Confidence vocabulary (carried from the audit)

`SOURCE` (inspected implementation path), `RECORDED` (a repo record/PR
states it — re-verify before implementing, some are stale), `QUALIFICATION`
(missing evidence for a claimed scope, not a proven wrong result),
`UNRESOLVED` (record explicitly leaves it tentative), `ARCHITECTURE`
(requirement for a future declared capability, not a reproduced defect).

## Entry format

```markdown
### <ID> — <title>

- **Area / edition:** <e.g. Randomization / edition-agnostic>
- **State:** OPEN | REPRODUCED | IN_PROGRESS | BLOCKED | CLOSED | WONTFIX
- **Confidence:** SOURCE | RECORDED | QUALIFICATION | UNRESOLVED | ARCHITECTURE
- **Evidence / reproducer:** <file:line, PR #, or session log pointer; a
  reducer path once one exists>
- **What it blocks:** <application workload / qualification claim / clause>
- **Closure requirements:** <what a CLOSED verdict must demonstrate>
- **Last verified revision:** <commit sha, or "not re-verified since audit">
```

---

### U01 — Xbar runtime/scoreboard/outstanding-request failures

- **Area / edition:** UVM and applications / edition-agnostic
- **State:** OPEN (checked traffic completes; pinned workload/UVM teardown qualification remains)
- **Confidence:** REPRODUCED
- **Evidence / reproducer:** `docs/conformance/session_logs/2026-09-04_global_constraint_solver.md`
  (5 xbar runtime logs show scoreboard mismatches; all 8 report outstanding
  requests on termination); PR #258; PR #261 (enum fix is explicitly not
  evidence these are fixed). No reducer exists yet — the session log notes
  the targeted probe hit the 300s CPU guard before completing.
- **What it blocks:** Real xbar application-level DV evidence; any claim of
  "OpenTitan xbar works."
- **Closure requirements:** Reproduce the first divergence with a bounded
  probe, reduce the simulator mechanism it exposes, and demonstrate at least
  one xbar smoke reaching normal completion with matched, checked
  request/response traffic and zero outstanding transactions at end of test.
- **Last verified revision:** `53b58890c` (P04): fresh smoke plus2repeats all complete115requests/230checked scoreboard items,4SEQPRTZMBwarnings,0errors/fatals and TEST FAILED CHECKS. All360exported source files match the prior replay. P04 fixes its independent live-parent kill reducer; it does not qualify U01. Pinned workload settings select UVM1.2, campaign library2020.3.1; no library edit or warning suppression. Evidence: `campaign-20260908/u01-after-p04`.

### Z01 — Joint solve-before stages unsupported

- **Area / edition:** Randomization / edition-agnostic
- **State:** OPEN, but **cited evidence is stale (updated 2026-09-16) —
  re-scope before doing anything else with this row.**
- **Confidence:** SOURCE (original), evidence refresh below is REPRODUCED.
- **Original evidence / reproducer:** `vvp/vvp_z3.cc` explicitly rejects
  `order_pairs` in the joint route ("solve before stages across objects are
  not supported"); PR #258.
- **2026-09-16 evidence refresh:** the exact cited string ("solve before
  stages across objects are not supported") no longer exists anywhere in
  `vvp/vvp_z3.cc` on current `main` — grepped directly, zero hits. Built a
  fresh cross-object `solve child.a before b;` reducer (a `Parent` class
  holding a `rand Child child` handle, ordering the child's property before
  the parent's own) against a current `main`-tip build: it does **not**
  hard-reject. It compiles with a loud, honest warning ("Constraint item in
  'order_c' of class Parent is not representable in the constraint solver
  and is ignored") — the ordering *directive* itself is dropped, not the
  constraint system — and `randomize()` still succeeds, with the
  *underlying value constraints* (including a shape where `b`'s legal
  range structurally depends on `child.a`, i.e. staging-dependent, not
  just a flat equality) correctly satisfied every time (20/20 iterations,
  both a plain-equality and a range-depends-on-child.a shape checked).
  **This is a materially different state than the row's original
  "explicitly rejects" framing** — satisfiability is preserved via the
  general joint solver even without honoring the specific staging.
- **NOT verified, and NOT claimed closed:** this row's actual closure bar
  is distribution correctness — "small-domain staged distributions with
  correct marginal/conditional probabilities" — not mere satisfiability.
  A single-sample (or 20-sample) correctness check proves the joint
  system is *solvable* consistently with the value constraints; it says
  nothing about whether the *probability distribution* of the solutions
  matches what §18.5.10 staged solving would produce (e.g. `child.a`
  drawn uniformly first, then `b` uniformly from the resulting legal
  range, vs. some other joint distribution a SAT-based simultaneous
  solve might produce instead). That needs a statistical-sampling
  reducer (many thousands of draws, checked against a hand-computed
  expected distribution), which this pass did not attempt.
- **What it blocks:** Any DV workload relying on cross-object
  `solve ... before` for *distribution* correctness specifically (not
  blocking plain satisfiability, which already works per the refresh
  above) — recorded as a shared xbar/runtime frontier in the same
  session log as U01.
- **Closure requirements (unchanged):** Small-domain staged distributions
  with correct marginal/conditional probabilities and graph rollback on
  failure; explicit rejection (or correct staged solving) preserved for
  shapes still out of scope.
- **Last verified revision:** b9de0be7f (stale). Z01A resolves bounded
  canonical integral stages locally (unmerged as of that note; unclear
  whether the warn-and-drop-directive-then-jointly-solve behavior found
  in the 2026-09-16 refresh above is Z01A's actual merged effect or a
  separate, later change — not traced further this pass). Ordered
  dist/randc and non-scalar/large-domain cases remain explicitly open per
  that same note.
- **Next step for whoever picks this up:** do not re-derive from the old
  "explicitly rejects" framing — start from the 2026-09-16 refresh above.
  Either (a) build the statistical-sampling reducer to settle distribution
  correctness, or (b) if distribution correctness turns out fine too,
  re-scope this row down to just the explicitly-still-open dist/randc/
  large-domain cases and close the plain cross-object scalar-ordering
  case formally with its own regression.

### C01 — Untranslated inline constraints are discarded (semantic degradation)

- **Area / edition:** Frontend/randomization / edition-agnostic
- **State:** CLOSED (silent-discard defect only; local implementation unmerged)
- **Confidence:** REPRODUCED
- **Evidence / reproducer:** `make_randomize_with_expr()` in `elab_expr.cc`
  warns and continues when an inline constraint cannot be lowered, instead
  of hard-erroring — the call can be built without the requested constraint.
- **What it blocks:** Trustworthiness of any `randomize() with { ... }` call
  whose constraint shape isn't recognized; a silent-degradation risk, not
  merely a missing feature.
- **Closure requirements:** Reduce a live unsupported inline-constraint
  shape; require either correct constraint execution or an explicit failure
  — never a successful solve that silently dropped the constraint.
- **Last verified revision:** 8f298eefe accepts and discards a selected foreach item in both editions; runtime returns success with 412736472 instead of required 123. Candidate passes all required local gates and review; remote CI required before merge. Unsupported expressions remain unimplemented.

### S01 — Cross-clock overlapping implication (SVA boundary)

- **Area / edition:** Assertions/SVA / IEEE 1800-2017 and 1800-2023 16.13.3.
- **State:** SUPERSEDED (bounded fixed-chain boundary already implemented).
- **Confidence:** VERIFIED
- **Evidence / reproducer:** Commit `0ff77277c` implements the fixed-chain
  overlapping boundary. Fresh `../evidence/campaign-20260908/s01/` runs cover
  coincident edges in both source orders, strictly later consequent ticks,
  positive/negative outcomes, preponed sampling and nested clock flow.
  Three reducers pass in both editions with default and legacy SVA modes
  (12 runs); independent review confirms this bounded classification.
- **Residual scope:** Variable-length antecedents and broader multiclock
  properties remain separate obligations; this is not complete SVA qualification.
- **Last verified revision:** `2be79b2c0`; existing clock-flow/nested-flow
  regressions also pass the required integrated suite. No implementation change.

### V01 — Exact merged type-coverage bin universe (coverage correctness)

- **Area / edition:** Functional coverage / edition-agnostic
- **State:** **Re-verified CLOSED 2026-09-16** (was stale-OPEN; V01A's fix
  is merged on `main` and covers this row's own stated closure
  requirements — see below). Originally: OPEN (V01A resolves bounded
  dynamic value-bin union locally).
- **Confidence:** REPRODUCED (original defect), then RE-VERIFIED FIXED
  against a fresh build of current `main` (not just re-read from an old
  evidence file).
- **Original evidence / reproducer:** `vvp/class_type.cc`'s `type_coverage`
  used a maximum registered dynamic-family size raised to the hit count —
  not an exact union for arbitrary disjoint instance bin sets.
- **2026-09-16 re-verification:** built the LRM's own §19.11.3 worked
  example fresh (`covergroup gt(int l,h); type_option.merge_instances=1;
  option.get_inst_coverage=1; coverpoint a { bins b[] = {[l:h]}; }
  endgroup`, `gv1=new(0,1)`, `gv2=new(1,2)`, sample `a==0` on `gv1` and
  `a==1` on both) against a fresh `main`-tip build (not a stale note):
  `gv1.get_coverage()` and `gv2.get_coverage()` both return exactly
  `66.6667`, `gv1.get_inst_coverage()` returns exactly `100.0`,
  `gv2.get_inst_coverage()` returns exactly `50.0` — all four values
  match the LRM's own stated answers exactly. (Two option-scoping
  mistakes were made and corrected while building this reducer —
  `merge_instances` is a `type_option`, not `option`, and
  `get_inst_coverage()`'s return value equals `get_coverage()` unless
  `option.get_inst_coverage` is explicitly set, both confirmed against
  LRM text before concluding anything — Icarus's behavior at each
  intermediate wrong-option step was itself correct per spec.)
- **This row's own closure requirements, checked against the existing,
  passing `ivtest/ivltests/sv_covergroup_merged_value_union.v` (registered
  for both `-g2017` and `-g2023`, part of every ivtest sweep this session
  with 0 failures):** disjoint instance domains (`unsampled disjoint`,
  `partial disjoint`), a retired instance still counted
  (`retired universe`), a non-100% partial-coverage result checked
  against a hand-computed oracle (`merged hit threshold` = 100/3), signed
  range crossing, fixed-size and scalar bins, and a 64-bit wide value bin
  with no enumeration — all present and passing. This is not "coverage
  reaches 100%" trivia; it is exactly the disjoint/overlapping/partial
  oracle-checked scope this row asked for.
- **LRM's second §19.11.3 worked example checked too** (`ga(abm)` with
  differing constructor-arg `auto_bin_max` per instance, giving 96
  cumulative auto-bins): this hits a DIFFERENT, already-diagnosed
  limitation, not a silent-wrong-answer regression of V01/V01A —
  `option.auto_bin_max = abm;` (`abm` a constructor argument, not a true
  elaboration-time constant) produces a loud `sorry: covergroup option
  'auto_bin_max' is not a constant; using default 64.` `auto_bin_max`
  itself apparently isn't constructor-arg-drivable at all yet (unlike
  `bins b[] = {[l:h]}` range bounds, which V01A's fix does handle
  per-instance); not a V01/V01A regression, and already meets the
  "unsupported behavior must produce a focused diagnostic" bar as-is.
  Not filed as its own row — genuinely minor (auto-bin-max is rarely
  made constructor-dependent in practice; the common case, a fixed
  `auto_bin_max` with constructor-dependent VALUE RANGES, is exactly
  what V01A already covers) — revisit only if a real corpus (OpenTitan/
  Caliptra) reducer needs it.
- **What remains genuinely unverified (not claimed closed):** transition-bin
  / cross-bin unions specifically under `merge_instances` (as opposed to
  the value-bin unions checked above). Re-open (or file a fresh,
  separately-scoped row) only if a reducer for that specific shape is
  found to fail — do not reopen this row generically without a concrete
  new reproducer.

### F00 — Hardware formal proof backend (PROGRAM item, not a bug)

- **Area / edition:** Formal verification / N/A
- **State:** OPEN
- **Confidence:** ARCHITECTURE
- **Evidence / reproducer:** `docs/conformance/iverilog_ieee1800_uvm_manifesto.md`
  places a proof engine in a later program; the audit's F01–F09 rows (sound
  transition-system lowering, property roles, bounded/unbounded search,
  counterexample replay, vacuity checks, backend soundness validation) are
  facets of this one program, not nine independent reproduced defects.
- **What it blocks:** Any claim of formal/model-checking capability beyond
  constrained-random Z3 solving for randomization (which is explicitly not a
  hardware model checker).
- **Closure requirements:** A published supported profile (finite state,
  legal constructs, reset/clock/X-Z treatment) plus a sound lowering,
  bounded-safety/cover search, and soundness qualification against known
  passing/failing designs — this is a multi-increment program; do not close
  it as one PR. Track F01–F09 as its sub-items when work actually starts.
- **Last verified revision:** N/A (architecture item).

---

## Excluded / already reconciled (do not re-open without new evidence)

These were checked during the audit that seeded this file and found to be
stale or already addressed — listed so they aren't accidentally re-promoted
from `blocker_inventory.json` as if still open:

- One-bit enum VPI-format assertion — fixed by merged PR #261.
- "Joint parent/child constraints entirely missing" — PR #258 implements a
  bounded joint route; only its residual contract (Z01 above, and the
  other Z02–Z14 rows in the fuller audit) remains open.
- "Solver UNKNOWN accepted as a successful model" — the class route rejects
  UNKNOWN, but the scope route still accepts unconstrained targets. The
  September 21 source finding in [discovered debt](DISCOVERED_DEBT.md) corrects
  the earlier blanket exclusion; scope runtime reproduction remains pending.

See `blocker_inventory.json` / `iverilog_uvm_blocker_audit.md` (as supplied
to the governance-bootstrap session) for the full 134-row inventory this
seed set was drawn from, and for the complete excluded/reconciled list.

## Campaign-resumed process work

### P01 — Null and empty parallel children are discarded

- **Area / edition:** Process execution / IEEE 1800-2017 and 2023 §9.3.2.
- **State:** CLOSED (bounded local implementation; not merged)
- **Prerequisite:** P03 resolved and locally validated at b9ffa4994. Reducers resumed from preserved Git stash.
- **Confidence:** SOURCE
- **Evidence / reproducer:** Existing fork-process-preservation patch; `ivtest/ivltests/sv_fork_null_child.v` and `sv_fork_empty_child.v` (current baseline verification pending).
- **What it blocks:** Correct join_any termination and process creation for empty children.
- **Closure requirements:** Correct join/join_any/join_none behavior; preserve sequential/assertion null actions; focused and integrated gates.
- **Last verified revision:** Campaign P01 checkpoint on b9ffa4994; all required local gates passed. See 2026-09-08 campaign evidence; closing PR/remote CI pending before merge.

### P02 — Singleton forks lose process identity

- **Area / edition:** Process execution / IEEE 1800-2017 and 2023.
- **State:** CLOSED (bounded local implementation; not merged)
- **Confidence:** SOURCE
- **Evidence / reproducer:** Preserved original worktree `sv_fork_singleton_process.v`; `dll_target::proc_block` flattens singleton joins.
- **What it blocks:** Process identity/control and per-child random stability.
- **Closure requirements:** Process identity, RNG ownership, suspend/resume/kill and task/sequential controls with required gates.
- **Last verified revision:** Campaign P02 checkpoint on a5788c259; all required local gates passed. See 2026-09-08 campaign evidence; closing PR/remote CI pending before merge.

### P03 — Function-spawned fork children execute synchronously

- **Area / edition:** Process execution / IEEE 1800-2017 and 2023.
- **State:** CLOSED (bounded local implementation; not merged)
- **Confidence:** SOURCE
- **Evidence / reproducer:** Preserved original worktree `sv_fork_function_children.v`; `do_fork_` function path can synchronously execute non-final children.
- **What it blocks:** Background process scheduling in functions.
- **Closure requirements:** Child execution starts after parent suspension/termination, including multiple children; required gates.
- **Last verified revision:** Campaign P03 checkpoint based on 49505f514; see 2026-09-08 campaign evidence. All required local gates passed; closing PR/remote CI pending before merge.

### Z01A — Bounded canonical integral joint ordering stages

- **Area / edition:** Randomization / IEEE 1800-2017 18.5.10, 2023 18.5.9.
- **State:** CLOSED (bounded local implementation; unmerged)
- **Parent:** Z01 (remains open beyond this bounded subcase).
- **Confidence:** REPRODUCED
- **Evidence / reproducer:** exact_joint rejects all order_pairs at current b9de0be7f; root-local ordering in existing sv_randomize_global_sampling_fail is legal but unsupported.
- **What it blocks:** Ordered small-domain parent/member-object sampling.
- **Closure requirements:** Exact stage projections, latest partial ordering, rollback, replay, callbacks/activation and required gates; keep ordered dist and non-scalar stages explicit unsupported.
- **Last verified revision:** b9de0be7f red reducer in both editions; candidate patch passes all required local gates and independent review; remote CI/merge pending.


### L01 — Procedural member foreach replaces a selected prefix with a new loop

- **Area / edition:** Procedural iteration / IEEE 1800-2017 and 2023 12.7.3.
- **State:** CLOSED (bounded local scope; remote CI required before merge)
- **Confidence:** REPRODUCED
- **Parent:** U01, preserved under evidence/campaign-20260908/u01.
- **Evidence / reproducer:** lookup.sv fails both editions at c57fbe3c5; inner foreach visits all device ranges despite an enclosing selected-device filter. Slang accepts both editions; Verilator runtime produces correct membership.
- **What it blocks:** Correct selected member iteration and unmodified xbar scoreboard address routing.
- **Closure requirements:** Correct terminal-only loop declarations/iteration, constant/variable/nested controls, Bison/focused/integrated gates and independent review; then replay U01.
- **Last verified revision:** b0ac00f47 passes paired/focused/integrated/full JSON/UVM and review. Unmodified U01 replay confirms corrected routing with four request checks and three matched responses; application remains open for its pre-existing fourth-response stall.

### L02 — Automatic block locals retain values across loop entries

- **Area / edition:** Lifetime / IEEE 1800-2017 and 2023 6.21, 6.8.
- **State:** CLOSED (bounded local scope; remote CI before merge)
- **Confidence:** REPRODUCED and ROOT_CAUSED
- **Parent:** U01; preserved contract and two-edition reducer in evidence/campaign-20260908/u01-loop.
- **Evidence:** Class-task for-loop bit local returns 1 on entry 2 instead of default 0. Emitted autobegin.shared stores it in the task frame. Same driver structure leaves rsp_done set after the first response.
- **Closure requirements:** Fresh per-entry storage/defaults with static and capture controls; required local gates, review and U01 replay.
- **Last verified revision:** e0dab7221 red in both editions. Candidate now passes 93 legacy / 50 JSON focus and make check, including automatic_events2, ancestor history 2,3, and recursive event ownership (prior UVM deadlock repaired). Independent review has no actionable finding. All local semantic gates pass: integrated4666/4661/0/2/3, VPI103, negative149, runtime15, JSON1558/0, UVM355/0/0 real DPI. Unchanged U01 replay on9218751e2 completes115 requests/230 checked items; zero errors/fatals. Four sequence-parent warnings still prevent application qualification.

### V01A — Exact constructor-dependent value-bin union

- **Area / edition:** Coverage / IEEE1800-2017 and2023 19.11.3.
- **State:** CLOSED (bounded local scope; remote CI before merge)
- **Parent:** V01; no complete type-option or arbitrary cross/transition universe claim.
- **Confidence:** REPRODUCED and ROOT_CAUSED
- **Evidence:** Paired sv_covergroup_merged_value_union; original LRM example returned100 instead of66.666667.
- **Implementation:** Register and merge resolved intervals for unsized value bins; preserve name/index identity for scalar/fixed bins. Unsampled and retired instances remain represented.
- **Validation:** Focus53/43, integrated4668/4663/0/2/3, VPI103, negative149, runtime15, JSON1560/0, real-DPI UVM355/0/0, make check and independent review passed.
- **Limits:** Default merge_instances weighted averaging and downstream huge-total saturation remain unqualified.

### V02 — Default type coverage silently merges instances

- **Area / edition:** Coverage / IEEE1800-2017 and2023 19.11.3, table19-3.
- **State:** CLOSED (bounded local scope; remote CI before merge)
- **Confidence:** REPRODUCED
- **Evidence:** evidence/campaign-20260908/v02/average.sv, both editions on6eee0480c return100 rather than50 for two equal-weight half-covered instances.
- **What it blocks:** Trustworthy default type coverage; current result falsely reports complete coverage.
- **Closure requirements:** Respect default/explicit merge mode and instance weighting with paired controls, complete required gates and independent review.
- **Last verified revision:** ac60732f3 implements default weighted instance averaging and explicit merged/public-instance dispatch with native typed option initialization. Focus65/55, integrated4680/4675/0/2/3, VPI103, negative149, runtime15, full JSON1572/0, real-DPI UVM355/0/0, make check and independent review pass.
- **Limits:** Parent V01 remains open. General type_option weighting, procedural static type-option assignment, goals/strobe and arbitrary cross/transition universes are not qualified by this increment.

### V03 — Overall coverage ignores covergroup type weights

- **Area / edition:** Coverage / IEEE1800-2017 and2023 19.7.1 table19-3,19.9,19.11.
- **State:** CLOSED (bounded local scope; remote CI before merge)
- **Confidence:** REPRODUCED and ROOT_CAUSED
- **Evidence:** evidence/campaign-20260908/v03/type-weight.sv; both editions onac60732f3 return75 instead of87.5 for scores50/100 with type weights1/3.
- **What it blocks:** Correct overall coverage; declared type priority is silently ignored.
- **Causal trace:** of_COVGRP_GET_ALL computes an unweighted arithmetic mean; group type-weight metadata is absent.
- **Closure requirements:** Exact group-level type weights, default/zero/eligibility controls, valid constant conversion, all required local gates and independent review.
- **Limits:** Coverpoint/cross type weights and procedural static option access remain separate obligations.
- **Last verified revision:** 2be79b2c0 implements group-level declared type weights in overall coverage. Focus75/65, integrated4690/4685/0/2/3, VPI103, negative149, runtime15, full JSON1582/0, real-DPI UVM355/0/0, make check and independent review pass. Separate type-weight tag preserves old bytecode/property ordering.

### S02 — Bounded variable-length multiclock antecedents

- **Area / edition:** SVA / IEEE 1800-2017 and 1800-2023 16.12.7, 16.13.3.
- **State:** SUSPENDED — attempt-identity design boundary; reducer retained.
- **Confidence:** REPRODUCED compile rejection at `2be79b2c0` in both editions.
- **Evidence:** `../evidence/campaign-20260908/s02/antecedent.sv` and paired
  compile logs; legal `a[*1:2] |=> @(posedge c2) b` is rejected.
- **Mechanism:** Two-domain and N-domain callers of `sva_mc_expand_chain_`
  require fixed antecedents. Mere request-count expansion does not establish
  the per-start implication verdict required when several endpoints match.
- **Closure:** Preserve each endpoint evaluation, aggregate truth and required
  action semantics, clock timing, sampling and cancellation for the exact
  claimed bounded subset. Corrected expectation is two failures for two starts,
  rather than three failures for three endpoints.

S02 coordination boundary: scalar cross-clock request counts erase the parent
identity needed for one verdict per starting attempt. A local count-only fix is
incorrect. Reusing NFA endpoint bookkeeping first requires correcting its
existing per-consequence verdict dispatch; S03 is selected independently on a
fresh wrong-result reducer. A future S02 design must preserve attempt identity,
open antecedent status and outstanding consequences across clock domains;
architecture expansion is not authorized by this suspension.

**2026-09-16 evidence check (compile-rejection claim only, not the
architectural question):** the row's own cited symptom ("legal
`a[*1:2] |=> @(posedge c2) b` is rejected") is stale — the identical
construct compiles clean (exit 0, no diagnostic) against a current
`main`-tip build, and a basic runtime smoke (100 time units, no
triggering `a`/`b` activity) neither crashes nor hangs. This does
**not** touch or resolve the actual open question (per-start vs.
per-endpoint verdict counting under overlapping multi-endpoint matches)
— that needs a carefully constructed multi-start/multi-endpoint
triggering scenario to verify, which requires real expertise in how
this specific construct unrolls into the NFA and was not attempted this
pass; the "architecture expansion not authorized" boundary and
SUSPENDED status both stand unchanged. Only the stale compile-rejection
framing is corrected here so a future pass doesn't waste time trying to
reproduce a rejection that no longer happens before it can even get to
the real (runtime verdict-counting) question.

### S03 — NFA implication verdicts are emitted per endpoint

- **Area / edition:** SVA / IEEE 1800-2017 and 1800-2023 16.12.7.
- **State:** LOCALLY VALIDATED — remote CI required before merge.
- **Evidence:** `../evidence/campaign-20260908/s03/attempt-verdict.sv` fails
  both editions at `2be79b2c0`: one start with two failing consequences emits
  two failure actions instead of one. Independent semantic review confirms.
- **Mechanism:** `pform_sva_nfa_try_assertion` dispatches each consequence
  verdict directly and releases antecedent slots without retaining parent
  verdict identity. Existing endpoint-fanout golds encode this defect.
- **Closure:** Aggregate consequence outcomes per attempt, including early
  failure, delayed success, vacuity, cancellation and end-of-simulation;
  retain independent endpoints and local snapshots. Correct affected golds
  only from reviewed semantics and run required gates.

S03 result: existing NFA endpoint fanout retains parent identity through all
consequences; one child failure terminates the parent once, and success waits
for antecedent closure and all child successes. Vacuous user actions, distinct
nonvacuous callbacks, local snapshots, same-tick slot reuse, disable/kill,
cover counts and parent-counted strong EOS are covered. All required local
gates/review pass: NFA58, focus55/20, integrated4692/4687/0/2/3,VPI103,
negative149,runtime15,JSON1584,real-DPI UVM355,make check. Finite cyclic-pool
limits, DD005 nonfanout vacuity, S02 multiclock identity and broader SVA/formal
qualification remain open. Evidence: campaign-20260908/s03.

### S04 — Missing vacuous user pass actions in single-clock implications

- **Area / edition:** SVA / IEEE1800-2017 and1800-2023 16.12.7,16.14.1.
- **State:** LOCALLY VALIDATED — required local gates and independent review pass; remote CI remains required before merge.
- **Evidence:** At locally validated61ca5f336, false antecedent `a |-> b`
  produces0pass/0fail instead of1pass/0fail in2017/2023, default/legacy modes.
  Four compile/runtime logs and reducer in campaign-20260908/s04.
- **Mechanism:** Nonfanout NFA dead-before-obligation path suppresses pass
  dispatch; legacy match-only injection loses vacuous attempts. Specialized
  callers use the same pass dispatcher; fixed/OR/AND progress and symbolic
  pre-match ages preserve first-loss vacuity. Unsampled and asynchronous
  cancellation includes nonunit integral true values.
- **Validated so far:** Four paired reducers, VPI callback distinction,
  focused legacy17/17, JSON8/8, NFA58/58, affected real-DPI UVM9/9, make check
  and independent code review. Full integrated4700/4695/0/2/3, VPI104/104,
  negative149/149, runtime15/15, JSON1592/0 and real-DPI UVM355/0/0 pass.
- **Limits:** DD-007 symbolic nonvacuous per-endpoint verdict behavior remains
  separate and unqualified; no complete parent-feature claim.
- **Closure:** Correct vacuous user actions per attempt while preserving sampling,
  cancellation, multiplicity, callback distinctions and S03 parent semantics;
  all required local gates and independent review, then remote CI before merge.


### S05 — Symbolic repetition implication parent verdicts

- **Area / edition:** SVA / IEEE1800-2017 and1800-2023 16.9.2,16.12.7,16.14.1.
- **State:** LOCALLY VALIDATED — reviewed S05 parent correction; remote CI required before merge.
- **Evidence:** One enabled start of a[*LO:HI] with overridden LO2/HI3 produces
  good1/0 and bad0/1 at length2, then good2/0 and bad0/2 at length3 in both
  editions. Correct parent results are early good0/0,bad0/1 and final
  good1/0,bad0/1. Reducer/logs: campaign-20260908/s05.
- **Mechanism:** Symbolic r_end/r_fire counts publish consequent endpoint
  actions directly, rather than retiring failed parents and waiting for
  antecedent closure before success. Current packed ages/mature counts must
  retain the necessary ownership without an arbitrary new cap.
- **Selection:** Standards correctness and parameterized application assertion
  relevance; this is a distinct symbolic engine from S03's qualified NFA path.
- **Scope:** Accepted symbolic consecutive-repetition implication paths,
  existing cancellation/sampling/Reactive behavior, empty/nonempty timing and
  repetition-bound overrides. DD-006, symbolic consequent-delay overrides DD-008,
  and S02 remain separate.
- **Closure:** Reviewed parent-verdict semantics with permanent regressions and
  all required local gates; remote CI remains required before merge.

- **S05 current validation:** Paired focus14/14 legacy+JSON in both engines;
  neighbor17/17+8/8, callback1/1, NFA58/58, make check0 and independent review
  pass. Full integrated4714/4709/0/2/3, VPI105, negative149, runtime15,
  JSON1606/0 and real-DPI UVM355/0/0 pass. This qualifies accepted symbolic
  consecutive repetitions with fixed ##0/##1 Boolean consequences and tested
  exact-window empty timing, not all SVA or symbolic consequent-delay overrides.


### S06 — Overridden symbolic SVA cycle delay is frozen to its default

- **Area / edition:** SVA and parameter elaboration / IEEE1800-2017 and1800-2023.
- **State:** LOCALLY VALIDATED — reviewed S06 delay correction; remote CI required before merge.
- **Evidence:** On validated a76c9f67a, LO1/HI2/D0 defaults with D1 override
  pass at tick2 and ignore a false final child at tick3 in both editions.
  Literal ##1 controls pass. Reducer and paired logs: campaign-20260908/s06.
- **Hypothesis:** Single-delay grammar folds a parameter default through
  pform_sva_const_long and deletes its expression; range-delay syntax already
  retains overridable expressions for ordinary instance elaboration.
- **Selection:** Silent timing miscompilation, ordinary parameter override
  correctness and parameterized application assertion relevance.
- **Scope:** Shared single-delay normalization and necessary instance-sized
  lowering; exact parent, cancellation, sampling and empty timing preserved.
  No new arbitrary delay cap or broader multiclock architecture.
- **Closure:** Paired semantic regressions, override/boundary controls,
  required full gates and independent review. Remote CI before merge.

- **S06 repaired scope:** Single named parameter/localparam cycle delays retain
  per-instance values. Delayed sampled histories align symbolic repetition
  endpoints with the current consequent; unmatched real-time ages retain
  vacuity. Direct/prefixed overlap/nonoverlap, bounded/unbounded parents,
  empty timing, cancellation and cover endpoint counts have paired controls.
  Shared self-sizing preserves substituted operand width/sign; invalid
  original negative grouped delays and unknown bounds reject per instance.
- **S06 remaining scope:** Arbitrary delay-expression parsing, broader formal
  lookup, unsupported composed/multiclock shapes and maximal-width arithmetic
  remain unqualified. A rejection control does not implement a legal shape.
- **S06 current validation:** Focus18/18 legacy+JSON in both engines;
  S05neighbors14/14+14/14,S04neighbors17/17+8/8; NFA58/58;
  integrated4732total4727pass0fail2NI3EF,VPI105,negative149,runtime15;
  JSON1624/0,real-DPIUVM355/0/0,makecheck and final source/test review pass.

### S07 — Nested parameterized sequence aliases fail expansion

- **Area / edition:** Sequence composition / IEEE1800-2017 and1800-2023.
- **State:** LOCALLY VALIDATED — reviewed nested-alias increment; remote CI required before merge.
- **Evidence:** campaign-20260908/s04/window-nested-alias.sv; Left/Right
  wrapping Pair(actuals) reports No function named Pair, while direct use
  works. Previously reproduced on61ca5f336; current-source check pending.
- **Scope:** Shared nested sequence expansion and actual binding; preserve
  lexical identity, recursion safeguards, temporal truth and ownership.
- **Closure:** Paired reducer/direct controls, permanent timing/binding tests,
  all required local gates and review; remote CI before merge.

- **S07 exact qualification:** Bare alias bodies recursively expand nested
  sequence calls in their declaration generate scope. Caller-supplied
  sequence actuals retain caller lookup. Active-path cycles reject before
  expansion; repeated legal uses retain independent cloned bodies.
- **S07 validation:** Paired focus12/12 legacy+JSON in both engines;
  S06neighbors18/18+18/18,S04neighbors17/17+8/8,NFA58/58;
  integrated4744total4739pass0fail2NI3EF,VPI105,negative149,runtime15;
  JSON1636/0,real-DPIUVM355/0/0,makecheck and final review pass.
- **S07 residuals:** Full dependency-graph validation across independent
  instances and pre-existing parameterized declaration-owned lookup remain
  unqualified; no general sequence-composition completion claim.

### L03 — Automatic Boolean event expressions share activation state

- **Area / edition:** Lifetime/events / IEEE1800-2017 and1800-2023 6.21,9.4.2.
- **State:** LOCALLY VALIDATED — reviewed Boolean activation state and supported input chains; remote CI before merge.
- **Evidence:** u01-loop/history-expression-preexisting.sv; two automatic
  invocations of posedge(value[2] | 1'b0) both trigger at2 instead of2,3.
  Freshly reproduced after validated L04 in both editions; mixed parent/local
  OR also wakes2,2 instead2,3 (evidence/l03/after-l04-* and mixed-*).
- **Scope:** Shared Boolean driver activation state/context and directly
  necessary selection, preserving existing runtime lifetime mechanisms.
- **Closure:** Paired reducer and lifetime/static controls, all required
  local gates and review; remote CI before merge.

- **L03 validation:** Paired focus12/12legacy+JSON,L02neighbors93/50,
  L04neighbors4/4,PART_PV ancestor history/reuse,NFA58/58,integrated4760total
  4755pass0fail2NI3EF,VPI105/105,negative149/149,runtime invariants,
  JSON1652/0,real-DPIUVM355/0/0,makecheck and final review pass.
- **L03 residuals:** BUF,NOT,mux and other expression families remain
  unchanged/unqualified; no general expression or application closure.

### L04 — Automatic integral defaults do not seed event history

- **Area / edition:** Lifetime/events / IEEE1800-2017 and1800-2023 6.8,6.21,9.4.2.
- **State:** LOCALLY VALIDATED — reviewed integral initialization prerequisite; remote CI before merge.
- **Evidence:** Paired current4a879babc default-negedge reducer fires at1 on
  unchanged partial zero write instead of actual negedge at3; evidence/l04.
- **Mechanism:** Integral slot reset sets storage without initial publication;
  current hooks precede context stack/live linkage.
- **Scope:** Post-link hook using existing activation infrastructure and
  automatic integral initial-value propagation, all allocation callers audited.
- **Closure:** Paired default/lifetime controls and all required gates/review;
  resume L03 only after validated baseline. Remote CI before merge.

- **L04 validation:** Paired focus4/4 legacy+JSON,L02neighbors93/93+50/50,
  mixedlifetime7/7+7/7,eventcontrols14/14+14/14,NFA58/58;
  integrated4748total4743pass0fail2NI3EF,VPI105,negative149,runtime15;
  JSON1640/0,real-DPIUVM355/0/0,makecheck and final review pass.
- **L04 residuals:** Qualification covers integral signal default publication;
  derived Boolean contexts (L03),other value types and broader initialization
  obligations remain separate.


### L05 — Selected associative class-member foreach loses index type

- **Area / edition:** Foreach/arrays / IEEE1800-2017 and1800-2023 12.7.3.
- **State:** LOCALLY VALIDATED — reviewed selected-member index typing; remote CI before merge.
- **Evidence:** campaign-20260908/l01/typed.sv: values[string] member loop
  index becomes int and visits zero entries, also seen before L01.
- **Scope:** Exact implicit-index type resolution and necessary selected-member
  elaboration, preserving prefix selection and existing iteration behavior.
- **Closure:** Paired reducer, key/selection/lifetime controls, all required
  local gates and review; remote CI before merge.

- **L05 mechanism:** Preserve selected target paths through parser declarations
  and foreach index typing; reuse existing type-only lookup to reach the
  terminal array key type without evaluating selectors.
- **L05 validation:** Focus10/10 legacy+JSON, foreach neighbors53/34,
  makecheck/review, NFA58/58, integrated4765/4770 with zero unexpected failures,
  VPI105, negative149, runtime checks, fullJSON1662/0 and real-DPI UVM355/0/0 pass.
- **L05 residuals:** Invalid same-name header selectors (DD-009), selected-array
  non-member typing and broader container obligations are not qualified here.

### V04 — Merged type coverage saturates wide bin totals before division

- **Area / edition:** Coverage / IEEE1800-2017 and1800-2023 19.11.3.
- **State:** LOCALLY VALIDATED — reviewed merged aggregate arithmetic; remote CI before merge.
- **Evidence:** class_type::type_coverage narrows exact dynamic cardinality
  to UINT64_MAX and saturates per-item sums; instance coverage already uses
  unsaturated real aggregation. Multiple named wide families can exceed64 bits.
- **Scope:** Preserve supported merged totals through percentage calculation,
  retaining bin identity, thresholds, weights and mode dispatch.
- **Closure:** Paired relative-error reducer/controls, all required local gates
  and independent review; remote CI before separately authorized merge.
- **Residuals:** ParentV01, transition-family cardinality and cross-bin universe
  obligations remain separate. No per-blocker PR under updated cadence.

- **V04 candidate:** Local128-bit merged total/hit accumulation; individual
  transition-family cardinality unchanged. Focus2/2+2/2, coverage neighbors75/65,
  makecheck and independent review pass. Integrated4772total4767pass0fail2NI3EF,VPI105,negative149,runtime checks,
  fullJSON1664/0,UVM355/0/0,NFA58/58 all pass.

### V05 — Constructed cross bins are omitted or misidentified in merged type coverage

- **Area / edition:** Coverage / IEEE1800-2017 and1800-2023 19.6,19.11.3.
- **State:** LOCALLY VALIDATED — exact supported constructed-cross union/count scope; remote CI before merge.
- **Evidence:** campaign-20260908/v05/cross.sv: two dynamic cross instances,
  six-bin union and two hits; type coverage0 instead33.333333, instance25 correct.
- **Scope:** Register supported automatic cross-bin names/counts for merged
  type coverage and union already-resolved active named properties, preserving
  per-instance topology and full product identity.
- **Closure:** Paired canonical identity/union controls, required full gates
  and independent review; remote CI before merge. ParentV01 remains open.

- **V05 candidate evidence:** Ordered component-name tuples registered only
  after successful topology validation; local counts map to canonical type
  counters, with active named-property union. Focus13/13 legacy+JSON,
  coverage neighbors75/65,V04 neighbors2/2,NFA58/58 and independent review pass.
  Includes named/arrayed transition identities and malformed-plan denominator
  assertions. Integrated4785total4780pass0fail2NI3EF,VPI105,negative149,
  runtime checks,fullJSON1677/0,real-DPIUVM355/0/0 and makecheck all pass.
  ParentV01 remains open; unsupported topologies, transition cardinality and
  unqualified options are not closed. No immediate PR under milestone cadence.


### V06 — Merged item coverage uses instance weights instead of type weights

- **Area / edition:** Coverage / IEEE1800-2017 and1800-2023 19.7.1,19.11.3.
- **State:** LOCALLY VALIDATED — exact declaration-time item type-weight scope; remote CI before merge.
- **Evidence:** v06/type-weight.sv has coverpoint scores50/0,type weights3/1,
  instance weights1/3. Type returns12.5 rather than37.5; instance12.5 is correct.
- **Scope:** Declared coverpoint/cross type-weight validation, metadata and merged
  aggregation. Preserve independent defaults, instance modes and old bytecode.
- **Closure:** Paired semantic/invalid-value controls, scoped regression oracle
  corrections for item isolation, all required local gates and independent review.
  Procedural static assignment and other type-option obligations remain separate.

- **V06 evidence:** Typed constant validator handles independent defaults,
  zero weights, group noninheritance, static/dynamic/implicit crosses and
  merge0/instance isolation. Temporary typed aliases preserve constructor and
  sample scope, including legal type queries and outer constant functions.
  Old bytecode fallback and new tagged metadata bounds are controlled.
  Focus22/22+22/22,coverage75/65,V04 2/2,V05 13/13,integrated4807total4802pass
  zero unexpected2NI3EF,VPI105,negative149,runtime,JSON1699/0,UVM355/0/0,
  NFA58/58,makecheck and independent final review all pass. DD010 remains open.


### V07 — Never-instantiated covergroup types lower cumulative coverage

- **Area / edition:** Coverage / IEEE1800-2017 and1800-2023 19.9,19.11,19.11.3.
- **State:** LOCALLY VALIDATED — never-instantiated type eligibility only; remote CI before merge.
- **Evidence:** v07/uninstantiated-type.sv reports0 before any instance and50
  after constructing one fully covered type; expected100 in both situations.
- **Root:** Compilation registers types whose static metadata merge1 scores
  without checking whether an instance ever existed. Existing live registry
  and retired-options marker already preserve the required population state.
- **Scope:** Shared type-coverage eligibility, preserving constructed/retired
  populations and independent type/instance weights; no new metadata or registry.
- **Closure:** Paired lifecycle controls, full required local gates and review.
  Broader parentV01 and other coverage obligations remain open.

- **V07 validation:** Six permanent lifecycle entries pass both harnesses,
  with paired baseline failures and zero-weight/retirement controls. V04/V05/V06
  and coverage neighbors pass; integrated4813total4808pass0fail2NI3EF,VPI105,
  negative149,runtime,JSON1705/0,NFA58/58,UVM355/0/0 realDPI actual-g2012,
  makecheck and independent review pass. Existing live/retired state suffices;
  no metadata, ABI or scheduler changes. Broader qualification remains open.


### U02 — Published UVM revision compatibility matrix

- **Area:** UVM release compatibility / qualification tooling.
- **State:** LOCALLY VALIDATED — requested acquisition/probe tooling complete; release compatibility remains partial.
- **Evidence:** Accellera official downloads lists 1.0/1.1/1.2,2017 and2020 families; current U01 encounters a UVM-version boundary.
- **Scope:** Pin official sources, keep releases available locally, run isolated unmodified-library compile/smoke probes and record exact failures.
- **Closure:** Reproducible acquisition and honest per-release evidence. Does not require all versions to pass or establish IEEE1800.2/application qualification; discovered compiler gaps are record-only during U02.

- **U02 result:** 15 releases available;2020.2.0/2020.3.0/2020.3.1 compile and
  execute factory/copy/phase/regex/HDL smoke with zero warnings/errors/fatals.
  Twelve versions fail compilation; see `uvm_release_matrix.md`. Official Git
  releases use pinned submodules, others verified archive downloads. Six offline
  evidence-integrity/source-preservation controls pass. No compiler fix or
  broad UVM/application/ABI qualification is included in this tooling closure.


### L06 — Empty queues of structs with member defaults are rejected

- **Area / edition:** Data types / IEEE1800-2017 and1800-2023 7.10,7.2.2.
- **State:** CLOSED for empty queue-container initialization at `4965219df`; broader structure defaults remain open.
- **Evidence:** OfficialUVM2020.3.2 uvm_reg_map.svh2058 declares
  uvm_reg_bus_op accesses[$]; the element has data=0. Compiler emits an
  unsupported-default diagnostic for the queue declaration.
- **Expected:** An uninitialized queue is empty; no nonexistent element gets
  member initialization. Preserve valid scalar defaults and invalid-type errors.
- **Validation:** Fourteen paired legacy/JSON regressions, 27/26 neighbors,
  integrated 4827 total / 4822 pass / 0 unexpected failures / 2 NI / 3 EF,
  VPI 105, negative 149, runtime invariants, JSON 1719/0, NFA 58/58,
  real-DPI UVM 355/0/0, make check and independent review passed.
- **Release replay:** Unmodified UVM2020.3.2 passes the former declaration
  failure, then reaches the independently preexisting DD013 queue-last lvalue
  assertion. This is not a release/application pass. Unsupported array shapes
  and invalid member-default diagnostics remain explicitly covered.
- **Publication:** Local semantic qualification is complete. Separate B01
  Windows export correction and required remote merge gates remain pending.


### B01 — Windows coverage API import-library exports missing

- **Area:** Build/API ABI export map, no language-semantic change.
- **State:** CLOSED — old/new export invariant and review passed; required Windows CI now passed on PR273 head abcfdf7fb84b36b030ea8d28b05fca73ca06be16.
- **Evidence:** job102955775883 link of vvp.tgt reports seven missing coverage
  API symbols; all are declared in ivl_target.h and implemented in t-dll-api.cc.
- **Root:** Missing ivl.def entries prevent Windows import-library linkage.
- **Closure:** Old/new invariant proof, exact exports, independent review and
  required Windows CI. Update existing PR273; no new PR or agent merge.


- **Windows evidence:** UCRT64 job102981118128 completed success at2026-09-10T18:56:21Z, including build/link, regression, UVM and installed frontend. MINGW64 and CLANG64 also passed. Export map unchanged from reviewed7c779ff28; macOS remains queued for overall PR, no merge performed.


### U03 — Select a pinned UVM release from the iverilog command line

- **Area:** User-requested driver and release acquisition integration.
- **State:** CLOSED at `c35d2ef36` — focused, registration, selected real-DPI smoke, installed frontend, review, integrated and full JSON gates passed.
- **Authorization:** User requests a UVM version picker in iverilog similar to VCS.
- **Gap:** The driver accepts --uvm-home but has no release-ID selector or
  available-release listing. Existing --uvm-version reports the bundled version.
- **Contract:** Add --uvm=<release> and --uvm-list, using acquired pinned sources;
  preserve -uvm, --uvm-home and reporting-only --uvm-version behavior. Connect
  the downloader to discovery without downloading during a compiler invocation.
  Diagnose unknown/missing versions and conflicting path/version options clearly.
- **Validation:** Driver parsing/resolution tests for valid, missing, invalid and
  conflicting selectors; listing; path with spaces; existing-option controls;
  real-DPI compile/run smoke using a known passing pinned release. Required
  repository gates and independent review remain in force. Selecting a release
  does not qualify its language support or turn current compile failures into passes.
- **Boundary:** B01 is safely suspended awaiting external Windows CI; U03 is
  independent of the export-map correction. L06 passed all local gates before
  installing the candidate driver. U03 is the sole active implementation task.

- **Final validation:** Integrated 4827 total / 4822 pass / 0 unexpected
  failures / 2 NI / 3 EF; VPI105, negative149, runtime15/15; JSON1719/0.
  Availability is separate from compatibility and IEEE1800.2 qualification.

### L07 — Queue-last element assignment aborts elaboration

- **Area / editions:** Queue lvalues, IEEE1800-2017 and IEEE1800-2023 7.10/7.10.1.
- **State:** CLOSED at `9a1b6beb3` for direct queue-variable element lvalues; class-member and other parent forms remain unqualified.
- **Evidence:** Unmodified UVM2020.3.2 uvm_field_op.svh112 assigns msg_queue[$].
  Minimal string queue assignment aborts both saved baseline and L06 candidate.
- **Root candidate:** Plain queue lvalue dispatch handles SEL_BIT but omits
  SEL_BIT_LAST and reaches the SEL_NONE assertion. Trace all related consumers
  before correcting the shared lowering path.
- **Scope:** Runtime last-element selection for direct queue variables and
  affected ordinary element assignment paths; retain empty/bounded queue,
  element-type, index evaluation and existing member-selection semantics.
  Any unsupported parent shapes remain explicitly scoped and recorded.
- **Closure:** Standards evidence, baseline red, permanent paired regressions,
  smallest causal patch, required integrated validation and official release
  replay. Removing the assertion alone is not implementation.

- **Final evidence:** Baseline aborts in both editions. Ten paired legacy/JSON
  tests, neighbors21/13, make check, independent review, integrated4837 total
  with zero unexpected failures, VPI105, negative149, runtime15/15, JSON1729/0,
  NFA58/58 and real-DPI UVM355/0/0 pass. Full 15-release replay is complete and
  baseline-valid: four smoke passes, eleven compile failures. No broad queue,
  UVM, application or formal-program completion claim is made.

### P04 — Process kill misses descendants in synchronous task frames

- **Area / edition:** Process runtime / IEEE1800-2017 and2023 9.7.
- **State:** CLOSED for live-parent descendant traversal; locally validated at `53b58890c63a48aa1943c7ef065db59f19cebef3`.
- **Evidence:** `u01-after-l07/kill_task_children.sv`; both edition runs report
  parent KILLED, child WAITING, counter continuing4to9 after parent.kill.
- **Cause:** Descendant kill traversal skips joined synchronous task frames;
  their live detached children are later reparented during frame cleanup.
- **Scope:** Live-parent kill through synchronous frames only. Terminal-parent
  kill DD-014 and application teardown qualification remain separate.
- **Closure:** Permanent task/frame/deep-descendant and sibling controls;
  focused and required integrated gates, independent review, then U01 replay.

- **P04 validation:** Six paired regressions and all required focused/integrated gates passed: legacy4843total0unexpected failures,JSON1735/0,real-DPIUVM355/0/0,NFA58/58,VPI105,negative149,runtime15/15,makecheck and independent review. U01 replay remains separate.

### L08 — UVM2020.1 resource-queue typing frontier

- **Area / edition:** Class-scoped type actuals, IEEE1800-2017/2023 6.20.3 and8.23.
- **State:** CLOSED for class-scoped type actual resolution and specialization identity; release-wide qualification remains open.
- **Evidence:** DD-011; original2020.1.0/1.1 compile logs in the pinned release
  matrix stop at nested resource-queue type/assignment errors.
- **Closure:** First causal reducer, applicable IEEE semantics and minimal
  implementation scope before any patch; permanent regression, required gates
  and review. No release-wide or application qualification by implication.

- **L08 candidate evidence:** Scoped resource-queue actual fails in both editions on the validated baseline; explicit equivalent type passes. Type-only class-member lookup and resolved specialization keys now pass ten permanent paired regressions in legacy and JSON runners, related17/15 controls and make check. Independent review clear after preserving dotted-path provenance through SVA cloning. Integrated legacy/VPI/negative/runtime, full JSON, real-DPI UVM and NFA remain required; no closure yet.

- **L08 closure:** Implementation47e6c87b3 passed all required local gates: legacy4853total4848pass0fail2NI3EF,VPI105,negative149,runtime15/15,JSON1745/0,NFA58/58,real-DPIUVM355/0/0,focused10/10each,neighbors17/15,makecheck and independent review. Original2020.1.0/1.1 compile but fail runtime as separately recorded in DD-011.

### U04 — Original UVM2020.1 DPI regex loading

- **State:** CLOSED at aa172f5f9 for legacy regex C ABI and real error propagation; original release phase qualification remains DD-017.
- **Evidence:** DD-011, results-gizcr5j0; both original releases compile but miss uvm_re_match/uvm_glob_to_re symbols at runtime, followed by BUILDERR.
- **Scope:** Establish declarations, loaded exports and causal reducer before authorizing a bounded patch. No library edits or release-wide qualification.

### U05 — Standalone DPI reporting callback

- **State:** CLOSED at a5eb76ebb after all required local validation; resume U04.
- **Evidence:** u04/report_bridge.sv compiles but callback count remains0; standalone umbrella defines exported report callback as no-op.
- **Scope:** Existing runtime export dispatcher adapter, preserved merged builds, argument/count and real-UVM reporting tests. U04 legacy regex reducers preserved; resume after validation.

- **U05 closure evidence:** Four paired baseline failures become four passes in relocated frontend S10; S1-S10,review,makecheck,NFA58/58,integrated4853total0unexpected,VPI105,negative149,runtime15/15,JSON1745/0,real-DPIUVM355/0/0 passed. No legacy regex compatibility claim from this reporting fix.

- **U04 closure:** All required local gates passed: paired ABI/error controls,original2020.1.0/1.1 ABI4/4,relocated frontendS1-S10,review,makecheck,NFA58/58,legacy4853total0unexpected,VPI105,negative149,runtime15/15,JSON1745/0,real-DPIUVM355/0/0. Full15release matrix remains4SMOKE_PASS,9COMPILE_FAIL,2RUNTIME_FAIL; no release-wide qualification inferred.

### U06 — Original UVM2020.1 phase execution

- **State:** CLOSED at aad6fe22b (semantic patch fe4e949b8), after all required gates.
- **Evidence:** Both original releases finish at time0 without the smoke marker or expected missing-traffic fatal, despite successful direct ABI checks.
- **Resolved scope:** Preserve recursive caller input context across nested argument calls; IEEE2017/2023 8.6 and13.5.1. Original sources unchanged; both2020.1 releases now execute intended smoke checks through time1.
- **Validation:** legacy4855/0,VPI105,negative149,runtime15/15,JSON1747/0,real-DPIUVM355/0/0,NFA58/58,makecheck,independent review,relocated frontendS1-S10. Paired reducer fails baseline/passes candidate in both editions. Full15release matrix6SMOKE_PASS9COMPILE_FAIL; original2020.1 smoke4/4 in2017/2023. DD018 output-copying scope was subsequently resolved by L09.

### L09 — Nested argument output copy-out loses caller automatic destination

- **State:** CLOSED at 3c44fd13b after all required local gates.
- **Evidence:** Preserved nested output control fails identically before/after U06; caller local remains unchanged.
- **Scope:** Explicit automatic copy-out phases select callee formal loads and caller destination reads/writes, preserving frame ownership and existing typed copying. IEEE2017/2023 8.6 and13.5.
- **Evidence at candidate:** Three permanent regression families fail baseline and pass both editions; focused JSON38/0, malformed bytecode6/6, NFA58/58, makecheck and independent review pass. Full legacy4861/0,JSON1753/0,real-DPIUVM355/0/0,VPI105,negative149,runtime15/15 and frontendS1-S10 passed; restored tools match frozen fingerprints. Class fixed-array property scalar output (DD019) was resolved separately by L10.


### L10 — Fixed-array class-property element output copy-out

- **State:** CLOSED at 051aeee8e after validated prerequisite L11 and all required local gates.
- **Evidence:** Legal scalar output actual holder.slots[index] emits a skipping warning and remains unchanged.
- **Scope:** Existing fixed property slot checks and typed property stores; preserve receiver/index context and invalid-index semantics. No unrelated container expansion.

- **L10 validation:** legacy4873total0unexpected,VPI105,negative149,runtime15/15,copyout6/6,JSON1765/0,real-DPIUVM355/0/0,NFA58/58,makecheck,focusedJSON50/0,focusedlegacy8/0,independent review,frontendS1-S10; restored root and unchanged frozen fingerprints. Fixed property elements only; broader output/array support remains separately scoped.

### L11 — Scalar output actuals must not be copied in

- **State:** CLOSED at b32df9a29 after all required local gates.
- **Scope:** Native output argument setup must skip caller reads, initialize automatic formals to defaults, retain static formals and preserve DPI open-array handling.

- **L11 validation:** legacy4865total0unexpected,VPI105,negative149,runtime15/15,copyout6/6,JSON1757/0,real-DPIUVM355/0/0,NFA58/58,makecheck,focused42/0,independent review,frontendS1-S10; root restored and frozen hashes unchanged.


### U07 — Legacy UVM member delay compatibility

- **State:** CLOSED at a83731194 after all required local gates.
- **Evidence:** Original1.2 #setting.offset fails parsing; same first frontier in older releases.
- **Classification:** Nonstandard unparenthesized member delay; both IEEE editions require parentheses. Use existing miscellaneous extension switch, preserving strict rejection and normal delay semantics; no library patches.

- **U07 validation:** legacy4881total4876pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,JSON1773/0,real-DPIUVM355/0/0,NFA58/58,makecheck,focusedJSON8/0,legacy8/0,delayneighbors40/0,independent review,frontendS1-S10; installed root restored and frozen hashes unchanged. Eight release smoke passes; six compile gaps and one runtime timeout remain. This closes only compatibility syntax under the existing miscellaneous-extension mode, not IEEE/UVM parent qualification.

### L12 — String character reads through unpacked struct members

- **State:** CLOSED at a85a256b1 after all required gates.
- **Evidence:** DD021 original UVM1.2 printer row.val[0] receives explicit unsupported struct-member index diagnostic.
- **Scope:** Correct bounded rvalue string indexing, preserving byte type, bounds and index evaluation. Static-local references and constraints remain separate blockers.

### L13 — Signed byte semantics of string character reads

- **State:** CLOSED at849a779ea after corrected index conversion and all required gates.
- **Evidence:** Ordinary s[0] with octal377 yields255 when widened, while getc and byte cast yield-1. Both editions6.16/6.16.3/6.11.3 specify signed byte semantics.
- **Scope:** Shared character-select typing and expression sizing, preserving unsigned packed bit/part selects.

- **L13 validation:** legacy4887total4882pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,JSON1779/0,real-DPIUVM355/0/0,NFA58/58,makecheck,focusedJSON6/0,legacy6/0,stringneighbors42/0,independent review,frontendS1-S10; installed root restored and frozen hashes unchanged. Fullrelease results-6pvdp6vh retain8smokepasses,6compilegaps,1timeout; normalized diagnostics and source hashes match U07. General class-property dispatch and constant-function string evaluation remain open.

- **L13 corrected validation:** 849a779ea; legacy4887total4882pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,JSON1779/0,real-DPIUVM355/0/0,NFA58/58,makecheck,focusedJSON6/0,legacy6/0,neighbors42/0,independent review,frontendS1-S10; root restored and frozen hashes unchanged. Release results-m_3ysaa5 retains8passes6compilefail1timeout with matching row sources and normalized diagnostics.

- **L12 validation:** a85a256b1;legacy4893total4888pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,JSON1785/0,real-DPIUVM355/0/0,NFA58/58,makecheck,focusedJSON6/0,legacy6/0,neighbors71/0,independent review,frontendS1-S10; root restored and frozen hashes unchanged. Original release sweep results-qb7873zh:8SMOKE_PASS5COMPILE_FAIL1RUNTIME_FAIL1RUNTIME_TIMEOUT. Full UVM release and application qualification remain open.

### L14 — Static local hierarchical references inside automatic scopes

- **State:** CLOSED at69ff60cc6 after all required gates.
- **Evidence:** Original1.2 visit.compiled_regex read/write rejected as automatic despite explicit static chandle declaration.
- **Semantics:** Both IEEE editions6.21 explicitly permit static-variable hierarchical references inside automatic tasks/functions, except unnamed blocks. Preserve automatic-variable rejection.

- **L14 validation:** 69ff60cc6;legacy4905total4900pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,JSON1797/0,real-DPIUVM355/0/0,NFA58/58,makecheck,focusedJSON12/0,legacy12/0,neighbors18/0,independent review,frontendS1-S10; root restored and frozen hashes unchanged. Release results-f9qr050b:8SMOKE_PASS4COMPILE_FAIL1RUNTIME_FAIL2RUNTIME_TIMEOUT; all15 source hashes unchanged, other14 normalized compile logs identical. UVM1.2 runtime timeout remains DD028.

### U08 — Inherited-method lookup causes UVM1.2 root recursion

- **State:** CLOSED at c9626a449 after all required local gates.
- **Evidence:** DD028, original1.2 compiles then times out300s with no runtime output.
- **Resolved scope:** Inherited unqualified method precedence over enclosing homonyms; receiver/task/virtual binding, local visibility and static-caller diagnostics covered under both editions. General access control remains DD029; original1.2 still fails legacy regex DPI (DD030).

- **U08 validation:** c9626a449;legacy4911total4906pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,JSON1803/0,real-DPIUVM355/0/0,NFA58/58,makecheck,focusedJSON6/0,legacy6/0,neighbors32/0,independent review and external-review reconciliation,frontendS1-S10; root restored and frozen hashes unchanged. Release results-eb3ghca7:9SMOKE_PASS4COMPILE_FAIL2RUNTIME_FAIL; no source changes.2017.0.9 now passes;1.2 reaches regex DPI errors.

### U09 — Legacy UVM regex DPI entry points

- **State:** CLOSED at19e7f5592 after all required local gates.
- **Evidence:** DD030/DD027, original1.2 and1.1d import uvm_dpi_regcomp/regexec/regfree; installed modern umbrella exports none of those names. Pinned legacy sources already contain the implementation.
- **Scope:** Provide the legacy C ABI on the Icarus backend with strict regex semantics, error reporting and handle lifetime; permanent coverage and original-release replay. No library-source edits or full application claim.


- **U09 validation:** Focused10/10 under2017/2023; legacy4911total4906pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,JSON1803/0,real-DPIUVM355/0/0,NFA58/58,makecheck,independent review and frontendS1–S10. Installed root restored and frozen hashes unchanged. Original15release sweep results-n2m35ki0:11SMOKE_PASS4COMPILE_FAIL; all source hashes unchanged. Exact cached-regex gap closed, full release/application qualification remains open.

### U10 — OpenTitan UVM1.2 selection and provenance

- **State:** CLOSED at aaf8df44c for source selection/provenance; application qualification remains open.
- **Gap:** Replay harness selects and fingerprints bundled UVM despite pinned OpenTitan commercial configurations selecting1.2.
- **Scope:** Forward an explicit acquired source root, record its actual fingerprint and replay the pinned debug crossbar with original1.2. Keep all application checking and failure criteria.

- **U10 validation:** aaf8df44c harness only, compiler19e7f5592 unchanged. Permanent self-test PASS, invalid path exit2, explicit root/src/environment/override normalization4/4, independent review clear, diff/YAML checks pass. Pinned OpenTitan7a3ad34 original1.2 replay records correct source hash885ba9f74652494aa132aaaa26c43e9f210f94cdf5a8d3a87064993ec9b35dc0 and fails compile74 at legacy macro expansion; zero application traffic, no pass claim. DD031 preserves next frontier.

### L15 — Pasted function-like macro names with numeric suffix

- **State:** CLOSED at aa356ab4d after required local validation and original1.2 replay.
- **Evidence:** DD031 original1.2 OpenTitan field macro pastes uvm_print_aa_string_int3 but reports a missing argument list for its shorter prefix.
- **Scope:** Prove text-substitution semantics, correct the causal preprocessor boundary and preserve permanent paired-edition regression. No upstream source modifications.

- **L15 validation:** aa356ab4d; macrofocuslegacy24/0,JSON6/0,independent review,makecheck,legacy4913total4908pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1805/0,real-DPIUVM355/0/0,NFA58/58,frontendS1-S10; installed root restored and frozen hashes unchanged. Full15release11SMOKE_PASS4COMPILE_FAIL; all statuses/source hashes unchanged. OpenTitan macro errors/cascades removed; next failure is three const-handle member assignment diagnostics, DD032. No application pass.

### L16 — Mutable property through a const class-handle variable

- **State:** CLOSED at5ba60567f after required local validation and original1.2 replay.
- **Evidence:** DD032, original1.2 OpenTitan rejects uvm_top.enable_print_topology assignment.
- **Scope:** Both-edition6.20.6 direct const-handle variable member writes, retaining handle/const-property/value-aggregate protection. No complete const qualification claim.

- **L16 validation:** 5ba60567f; focusedlegacy8/0,JSON8/0,neighborslegacy18/0,JSON32/0,independent reviews,makecheck,legacy4921total4916pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1813/0,real-DPIUVM355/0/0,NFA58/58,frontendS1-S10; root restored and frozen hashes unchanged. Full15release11SMOKE_PASS4COMPILE_FAIL; all statuses/source hashes unchanged. Original1.2 OpenTitan replay42522: compiler0/runtime0,9.964s,152requests/288scoreboard items,0UVMwarnings/errors/fatals,TEST PASSED CHECKS and normal finish17625626ps. OverallDEBT from five compile-time null-fallback diagnostics on compound array-member operations; no application qualification. No waived checks/source edits.

### L17 — Integral compound updates of dynamic-array properties

- **State:** CLOSED at d8e974913 after all required local gates and original1.2 application replay.
- **Evidence:** DD035, five original1.2 register-item array updates emit null fallbacks.
- **Scope:** Typed integral element compound updates with single index evaluation, receiver/width preservation and invalid-index no-write behavior. No full compound/container qualification claim.

### L18 — Resolved property signedness in compound assignment

- **Status:** CLOSED at9791e6411; signedness prerequisite for suspended L17.
- **Evidence:** Signed scalar class property -64 /= 2 produces2147483616, expected-32. NetAssign_ signed_ is default-false for property shapes.
- **Scope:** Use resolved integral selected type in compressed-assignment elaboration. Paired signed/unsigned/part-select regressions and all required gates. No dynamic-array compound qualification before L17 resumes.

L17 coordination boundary: suspended with full partial patch/tests at
`evidence/campaign-20260908/l17/partial.patch`. Focus exposed prerequisite
operand width/state loss and signedness loss before target lowering. L18
handles signedness; DD036 preserves width/state debt. No L17 closure.

L18 closure: focused paired-edition/neighbor tests, independent review and all
required local gates pass; original15release statuses unchanged. Only direct
integral property signedness is resolved. DD036 width/state preservation and
L17 dynamic-array lowering remain open.

### L19 — Preserve four-state compound operands

- **Status:** CLOSED at72a97c038; state-conversion prerequisite for suspended L17.
- **Evidence:** On validated9791e6411, bit[7:0] value=1;value+=logic X yields1 in both editions; expected0 after unknown arithmetic result is assigned to bit.
- **Scope:** Delay destination two-state conversion until after the integral compound operator. Width preservation remains separate DD036 work. All required gates apply.

L19 closure: paired four-state operand and two-state result checks, signedness/
concatenation neighbors, independent review and all required local gates pass.
DD036 operand width and L17 target lowering remain open.

### L20 — Integral compound operation widths

- **Status:** CLOSED atfe12166bd; compressed-vector width prerequisite for suspended L17.
- **Evidence:** On validated72a97c038, logic8bit128 /=32'd256 producesX instead0 in both editions. L17 also demonstrates wide shift count truncation.
- **Scope:** Natural/context RHS width through compressed elaboration and shared vector operation sizing before final result truncation. Preserve existing receiver/index lowering; no new runtime instructions. All required gates apply.

L20 closure: paired constant/runtime widths, signedness/context, self-determined
shift counts, property parts and array/queue cases pass with all required
local gates. Associative front-end expansion remains residual DD036 debt; no
complete associative or parent compound qualification. L17 can now resume.

L17 resumes after validated L18/L19/L20 onfe12166bd. Original red/partial patch
are preserved; adapt append-only manifests and reuse the validated width helper.
All L17 gates/application replay remain required before exact-scope closure.

### L21 — Captured class-root notification preserves rebound handles

- **Status:** CLOSED at1146d2187; captured class-root runtime prerequisite for resuspended L17.
- **Evidence:** Standalone scalar h.value+=rebind() mutates original but restores old h during notification. Captured root delivery overwrites RHS reassignment.
- **Scope:** Guard captured class-root delivery with live binding identity while preserving alias/property events and contexts. All required gates apply. L17 resumed patch is preserved as partial-after-l20.patch.

L21 closure: replacement/null rebind, retained-alias/property events, unchanged
root and automatic-context controls pass with all required local gates. Guard
is limited to captured non-struct class roots; value aggregates/VIF remain
unchanged. L17 can resume on the validated runtime.

L17 closure after validated L18/L19/L20/L21 prerequisites: d8e974913;focuslegacy2/0,JSON2/0,neighborslegacy24/0,JSON23/0,original red passes both editions,makecheck,independent source review;legacy4931total4926pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1823/0,realDPIUVM355/0/0,NFA58/58,frontend97109exit0 all scenarios;install restored and five frozen hashes match. Complete15release results-3d_bbaiu11SMOKE_PASS4COMPILE_FAIL;all15 statuses/source/archive hashes match L21.

Original1.2 OpenTitan debug-crossbar replay6645: PASS,compiler0/runtime0,10.177s,152hostrequests/288scoreboarditems,0UVMwarnings/errors/fatals,compile semantic debt0/runtime debt0,TEST PASSED CHECKS and normal finish17625626ps. Original corpus7a3ad34 clean;UVMsrcSHA885ba9f74652494aa132aaaa26c43e9f210f94cdf5a8d3a87064993ec9b35dc0 unchanged. Actual -g2012,one default-seed smoke invocation;no paired-edition/multi-seed/full OpenTitan qualification. Two existing benign runtime lines report discarded $system return value.

### L22 — Built-in process::state nominal enum type

- **State:** CLOSED at4a102ee47 after all required gates.
- **Evidence:** Original UVM1.0p1 uvm_phases.svh2824 function return type fails visible-class lookup on d8e974913.
- **Scope:** 2017/2023 9.7 declared state enum and typed status/constants, preserving 6.19 nominal enum semantics. No scheduling redesign or full UVM1.0p1 qualification.

L22 validation: 4a102ee47;focuslegacy6/0,JSON6/0,neighborslegacy16/0,JSON10/0,makecheck and final independent review;Bison563SR1122RR,parse.output identical;legacy4937total4932pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1829/0,realDPIUVM355/0/0,NFA58/58,frontend18561exit0 all scenarios;install restored and five frozen hashes match. Complete15release results-p7axbpcu11SMOKE_PASS4COMPILE_FAIL;all15 source/archive hashes and statuses match L17,1.0p1 process::state error removed.

Bare class-scoped module declarations remain DD039; no full process or UVM1.0p1 qualification. Next exposed nested-background fork error is DD040.

### L23 — Nested joins in function-spawned background processes

- **State:** CLOSED at58edf8034 after required validation.
- **Evidence:** DD040 and both-edition reducer reject join_any within outer function fork/join_none.
- **Scope:** 13.4.4 task-legal background children using existing isolated elaboration context; retain direct function blocking-join errors. No scheduling/lifetime redesign or full UVM qualification.

L23 validation: 58edf8034;originalred both editions PASSED/no diagnostics,focuslegacy4/0,JSON4/0,existingfunctionfork2/0 both,neighborslegacy43/0,JSON33/0,makecheck and final independent review;legacy4941total4936pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1833/0,realDPIUVM355/0/0,NFA58/58,frontend38601exit0 all scenarios;install restored and five frozen hashes match. Complete15release results-2hbuhcyt11SMOKE_PASS4COMPILE_FAIL;all15 statuses/source/archive hashes match L22. Nested-fork diagnostic removed from1.0p1/1.1a;each retains three void-cast-of-void errors.

### L24 — Void function calls in void-cast statements

- **State:** CLOSED at795d9f360 with test reconciliation8afc61443 after required validation.
- **Evidence:** DD041, both-edition calls with argument/output effects rejected; original1.0p1/1.1a each fail three such calls.
- **Scope:** Dedicated13.5/A.6.9 function-call statement grammar, preserving actual effects and task/void-expression/deferred-action restrictions. The grammar/prose reading is explicitly recorded as inference; no compatibility bypass or upstream source edits.

L24 validation reconciliation: the initial integrated run found the legacy-only
`sv_void_cast_fail1` expected the dedicated statement to be rejected. That obsolete
expectation is replaced by direct void-function expression rejection; the new
paired tests own legal-statement coverage. Independent review agrees. This does
not qualify historical2005 acceptance. Required rerun remains pending.

L24 final validation: 795d9f360 with test reconciliation8afc61443;originalred both editions PASSED,no diagnostics;focuslegacy7/0,JSON4/0,neighbors23/0 both,makecheck,independent review;legacy4945total4940pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1837/0,realDPIUVM355/0/0,NFA58/58,frontend93910exit0 all scenarios;install restored and five frozen hashes match. Complete15release results-6_pvcxya11SMOKE_PASS2COMPILE_FAIL2RUNTIME_FAIL;all15 source/archive hashes match L23. 1.0p1/1.1a now compile/start but missing older DPI prevents pass;1.0p1 also unresolved-functor/cast diagnostics.

### U11 — Original UVM1.0p1/1.1a DPI entry points

- **State:** CLOSED at e18128369 after required validation.
- **Evidence:** DD042 missing old command-line/regex symbols in unmodified sources.
- **Scope:** Real argv iteration/restart and metadata, strict cached regex adapters;
  no original-source edits or unrelated legacy runtime/recording fixes.

U11 final validation: e18128369;both-edition red failed missing old DPI entrypoint;focused8/0,makecheck,independent code/evidence review;legacy4945total4940pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1837/0,realDPIUVM355/0/0,NFA58/58,frontend41504exit0 all scenarios including oldABI both editions;install restored and five frozen hashes match. Release results-zyhh1jv9 complete/baseline_valid,all15source/archive hashes unchanged. Reviewed12clean smoke passes,1disqualified1.0p1 runtime,2compilefails;raw1.0p1SMOKE_PASS rejected due existing3placeholder and2cast diagnostics. 1.1a clean new smoke pass through time1.

### U12 — Simulator diagnostics cannot be clean release smoke passes

- **State:** CLOSED at1654dc4c9 after required harness validation.
- **Evidence:** DD043 original1.0p1 false-positive runtime row.
- **Scope:** Existing shared classifier/offline tests and fresh release evidence;
  no compiler changes or repair of underlying runtime diagnostics.

U12 final validation: 1654dc4c9;newdiagnosticnegative failed8subcases beforefix,all8offline matrix tests pass;all13historical runtime logs correct12accept/1reject;independent review caught/fixed quoted-UVM_INFO falsepositive with permanent control. Fresh15release results-fm8uvyiv complete/baseline_valid,12SMOKE_PASS1RUNTIME_FAIL2COMPILE_FAIL;all15source/archive and alltoolhashes unchanged vsU11. Only1.0p1 rawstatus corrected;no compiler/DPI or IEEE semantic gain. Frozen U11 fivehashes match.

### L25 — Integral function-name variable passed by reference

- **State:** CLOSED atc58035f49 after requiredvalidation.
- **Evidence:** Both-edition7-to12 ref-update reducer fails; three original1.0p1
  build_coverage functions bind a ref formal to an omitted return signal.
- **Scope:** True reference storage under13.4.1/13.5.2, retaining return and
  lifetime semantics. Address-taken return variables use existing signal/context storage.
  Callback cast/typeidentity diagnostics remain separate.

L25 final validation: c58035f49;originalred/interactions both editions PASSED,no diagnostics;focuslegacy2/0,JSON2/0,neighborslegacy58/0,JSON46/0,makecheck and independent design/code review;legacy4947total4942pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1839/0,realDPIUVM355/0/0,NFA58/58,frontend88452exit0 allscenarios;installrestored and fivefrozenhashesmatch. Complete15release results-3v03d7qs12SMOKE_PASS1RUNTIME_FAIL2COMPILE_FAIL;all15statuses/source/archivehashes unchanged vsU12. Original1.0p1 threeplaceholder diagnostics gone;two callbackcast errors remain.

### L26 — Matching class parameters with independent defaults

- **State:** CLOSED at e3666fd07 after required validation.
- **Semantics:** Both IEEE editions 8.25 require matching effective class-type
  parameters of the same generic declaration to select one type.
- **Cause:** Existing canonical key path requires a dependent default, so
  independent omitted/explicit defaults incorrectly retain source identity.
- **Scope:** Concrete multi-class-type parameters with bare nominal class defaults; preserve unresolved
  forwarding and owner identity. Generic-template initialization remains separate.
- **Evidence:** `evidence/campaign-20260908/l26/default-pair.sv` and `.json`;
  larger original-callback reducer and passing controls retained.

L26 final validation: e3666fd07; both-edition15line reducer PASSED; focuslegacy2/0,JSON2/0,paramneighbors23legacy/16JSON,identity/dependent/seedneighbors6/0each,makecheck and independent design/code review; legacy4949total4944pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1841/0,realDPIUVM355/0/0,NFA58/58,frontend29502exit0 allscenarios; installation restored and five sha256-final hashes match. Complete15release results-8054igtp12SMOKE_PASS1RUNTIME_FAIL2COMPILE_FAIL; all15statuses/source/archivehashes matchL25, original1.0p1 stilltwo callbackcasts.

### L27 — Generic master static initialization

- **State:** CLOSED at8f2252dd3 after required validation.
- **Semantics:** Both8.25 assign static storage to concrete specializations;
  the generic class itself is not a type.
- **Cause:** `netclass_t::elaborate` emits a static initializer process even
  for the unspecialized generic master. One requested specialization causes
  two registration side effects.
- **Scope:** Generic masters only; preserve actual concrete/default and ordinary
  class initialization. Seed-derived forwarding lifecycle remains DD044.
- **Evidence:** `evidence/campaign-20260908/l27/seed-init.sv` and `.json`.

L27 final validation: 8f2252dd3; both-edition red PASSED; focuslegacy2/0,JSON2/0,static/identityneighbors37legacy/25JSON,makecheck and independent design/code review; legacy4951total4946pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1843/0,realDPIUVM355/0/0,NFA58/58,frontend78203exit0 allscenarios; installation restored and five frozen hashes match. Complete15release results-ni3wgjii12SMOKE_PASS1RUNTIME_FAIL2COMPILE_FAIL;all15statuses/source/archivehashes matchL26;original1.0p1 stilltwo callbackcasts.

### U13 — Literal legacy DPI arguments versus GNU runtime options

- **State:** CLOSED, exact harness scope on9006baa15. Prior published2785
  Linux CI failed before simulation with `vvp: invalid option -- f`.
- **Cause:** The fixture invocation lacks `--` before the program/argv.
  `vvp/main.cc` deliberately allows GNU getopt permutation.
- **Scope:** Invocation separator only; retain literal `-f` iteration assertions,
  metadata/regex behavior, and all diagnostics. Local frontend and fresh Linux
  CI are required; no compiler/DPI semantic change.

U13 validation complete: local isolated frontend35171exit0 with all original
argv/regex checks retained and installed hashes restored. Fresh published
9006baa15 jobs103200770181 (Ubuntu22.04) and103200770250 (Ubuntu24.04)
both succeeded; logs confirm legacy_10_dpi IEEE2017 and2023 PASS on both.
Evidence: `evidence/campaign-20260908/l29/ubuntu2204.plain.log` and
`ubuntu2404.plain.log`. Independent review clear. Other PR275 platform
checks remain pending; this closure is not PR readiness or merge permission.

### L28 — Unresolved forwarded type initializer side effects

- **State:** CLOSED at77cce610b after required local validation.
- **Cause:** Symbolic forwarding requests have specialized-instance metadata
  while their actual retains generic source lineage; static init ignores this.
- **Scope:** Existing deferred-type predicate at process registration; preserve
  concrete cache reuse, initialization analysis and ordering. DD044 evidence.
- **Coordination:** U13 remains awaiting fresh Linux CI on9006baa15; it only
  changes a fixture command. L28 has no dependency on that pending harness gate.

L28 final validation: 77cce610b; counter and callback reds both editions PASSED/no diagnostics; focuslegacy4/0,JSON4/0,static/identityneighbors37legacy/25JSON,L27neighbors2/0each,makecheck and independent design/code/evidence review; legacy4955total4950pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1847/0,realDPIUVM355/0/0,NFA58/58,frontend91254exit0 allscenarios;installation restored/five frozen hashes match. Complete15release results-edrgslxb13SMOKE_PASS2COMPILE_FAIL;only1.0p1 statusimproves,all15source/archivehashes unchanged. Original1.0p1 cleanruntime/time1 with zeroUVMwarnings/errors/fatals;existingcompileconstraint/castlimitations remain,notfullUVMqualification.

### L29 — Abandoned procedural block scope during parser recovery

- **Status:** CLOSED at9229c24e7, bounded procedural-block recovery; robustness only.
- **Evidence:** `evidence/campaign-20260908/l29/one-loop.sv`, both editions
  abort134 on validated77cce610b; legal replacement compiles0. Existing parser
  trace shows a discarded begin midrule leaves lexical scope active, then
  normal enclosing for reduction reaches a scope assertion.
- **Scope:** Release discarded procedural block scopes at their ownership
  boundary; retain syntax rejection and valid nested/named/loop behavior.
- **Not claimed:** Recording support, another UVM release pass, or all parser
  recovery. Foreach carrier recovery remains DD045. U13 Linux CI has passed.

L29 final validation: 9229c24e7; original malformed reducer and all five procedural block forms reject normally in both editions; paired runtime lifetime/label/foreach/fork controls PASS. Focus12legacy/12JSON,neighbors68legacy/57JSON,makecheck and independent design/code/test reviews clear. Bison563SR1122RR unchanged. Legacy4967total4962pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1859/0,realDPIUVM355/0/0,NFA58/58,frontend74117exit0 allscenarios;installation restored/five frozen hashes match. Complete15release results-bwek89ja13SMOKE_PASS2COMPILE_FAIL;all status/source/archivehashes unchanged vsL28. 1.1b/c now normalcompile32 without assertion,not new UVM passes.

### L30 — Direct class-scoped type declarations at module scope

- **Status:** CLOSED at34787868e; bounded DD039 direct complete-class type route.
- **Reducer:** Complete class holder with typedef int state; module declares
  holder::state s. Both editions reject as invalid module instantiation.
- **Scope:** Reuse class type resolution at the module declaration frontier;
  preserve type identity, variable shapes and illegal-prefix/access rejection.
- **Authority:** Both editions6.18/8.23; unresolved prefix restrictions remain.
- **Evidence:** `evidence/campaign-20260908/l30/`; no fullclass/UVM claim.

L30 final validation: 34787868e; originalredcompile0/no diagnostics both editions; permanentfocus12legacy/12JSON,neighbors43legacy/32JSON,makecheck and independentdesign/code/ownershipreviewclear. Bison563SR1122RRunchanged. Legacy4979total4974pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66,fullJSON1871/0,realDPIUVM355/0/0,NFA58/58,frontend21313exit0 allscenarios;installation restored/fivefrozenhashes match. Complete15release results-jz6zk_cb13SMOKE_PASS2COMPILE_FAIL;allstatuses/source/archivehashes unchanged vsL29. No fullclass/UVM qualification claim.

### L31 — Associative compound expression typing

- **Status:** CLOSED at0a4e7d639; bounded DD036 associative expression typing.
- **Reducer:** Signed byte associative element -64/=2 gives96 instead of-32
  in both editions. Expansion emits unsigned division.
- **Scope:** Resolved element signedness and binary operand width/state through
  final store; mixed unsigned and self-determined shift controls required.
- **Authority:** Both editions11.4.1/11.6/11.8; evidence l31.

### Campaign priority — Eliminate remaining behavior-changing compile-progress paths

User-directed follow-on after the UVM smoke campaign: implement and qualify
correct semantics for every remaining compile-progress stub or fallback that
emits incorrect behavior. This includes silent degradation, not only diagnostics.
An unsupported error, removed warning, or smoke pass does not close a legal
feature. Select one concrete blocker at a time using reducers and applicable
IEEE semantics; existing registries are not an exhaustive inventory.

Confirmed initial evidence is original1.0p1 `results-jz6zk_cb/compile.log`
(per-release `1.0p1/compile.log`): ignored `pick_sequence` constraint at
uvm_sequence_base.svh949, and class-cast bits reinterpretation at
uvm_phases.svh1951. Reproduce exact semantic effects before selecting each
implementation contract. A constant-loop warning alone is not a stub.
L31 remains active; this priority does not authorize unrelated edits in its patch.


User follow-up explicitly authorizes a sweep of **all fallbacks**, including
silent paths and qualification-harness substitutions. DD046 records the first
tracked-source inventory, source-confirmed categories, false-positive rules,
and remaining semantic triage. This is discovery work, not another governance
bootstrap. Fix behavior-changing cases after UVM smoke, with one active blocker.

L31 final validation: 0a4e7d639; both-edition signed/mixed/shift/wide/four-state and local/property reducers PASS; permanentfocus2legacy/2JSON,neighbors125legacy/92JSON,makecheck and independentdesign/code/ownershipreviewclear. Integrated92982exit0:legacy4981total4976pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66. JSON7147exit0:1873/0. UVM32316exit0:REAL DPI355/0/0. NFA58/58. Frontend49875exit0 allscenarios;installation restored andfivefrozenhashes match. Complete15release results-322hzu4s13SMOKE_PASS2COMPILE_FAIL,allstatuses/source/archivehashes unchanged vsL30. No full associative/UVM qualification claim.


### U14 — Native legacy recording ownership and lifecycle

- **Status:** CLOSED for bounded lifecycle scope on native ARM64; semantic `729edce3c`, test/CI coverage `79885f484`. DD038 remains OPEN.
- **Original gap:** Native owner/lifecycle API absent; both-edition DPI owner reducer
  compiled but failed at runtime. Original1.1b/c recording macro gaps preserved.
- **Scope:** Explicit legacy recorder, real lifecycle journal, owner/kind/state
  validation and cross-owner links using original1.1d API. No automatic install
  or fake attribute macro. Full typed capture/bootstrap remain required.
- **Evidence:** `evidence/campaign-20260908/u14/`; ACTIVE_WORK owns exact contract.

U14 final validation: U14 semantic729edce3c; test/Windows-CI coverage79885f484. Installed native lifecycle/exclusive-text checks both editions and POSIXIOfailure pass; original1.1d realchild/component,wrongowner,stream/transaction rollback,recorder switch,exclusive/replacedfiles and journal-failure tests pass. makecheck and independent design/code/failure-path reviews clear. Integrated20014 exit0:4981total4976pass0fail2NI3EF,VPI105/0,negative149/0,runtime15/15,copyout6/6,exports66. JSON82380 exit0:1873/0. UVM57598 exit0:REAL DPI355/0/0. NFA45081 exit0:58/58. Releases32494 results-y5czc48y complete/baseline_valid13SMOKE_PASS2COMPILE_FAIL,all15status/source/archivehashes unchanged vsL31; separate1.1d lifecycle gate passes2017/2023. Frontend97996 exit0 allS1-S11;installation restored/six frozen hashes match. Bounded ARM64 local lifecycle validation only; typed capture/default installation/1.1b/c and fullUVM qualification remain open. Windows CI wired,execution not claimed.


### U15 — Lossless native recording value capture

- **Status:** CLOSED 2026-09-11 for the packed/real/string attribute-capture
  scope. Semantic `7db0431ff` (registration) + `da8d8c58c` (encoder) +
  `c0a8592eb` (string-dispatch fix). A new systf, `$ivl_uvm_record_attribute`
  (uvm_dpi/uvm_recording.cc), dispatches on `vpi_get_value(vpiObjTypeVal)`:
  packed captures every aval/bval word with declared size/sign; real captures
  exact IEEE754 bits (not decimal text); string reads `vpiStringVal` first
  and retries with `vpiVectorVal` only on a length mismatch against `vpiSize`
  under either unit convention the two backing VPI classes use, which is
  reachable in practice only for a literal whose value contains an embedded
  NUL (38.15 licenses that retry for `vpiStringConst`; L32 is the prerequisite
  that makes it correct). Unknown, wrong-kind, already-ended and
  already-freed transaction handles are all rejected before any journal
  write, with a nonzero simulation exit status since the task has no other
  return channel. All six required gates pass with durable exit files:
  integrated exit0 (unaffected by this change, reused from `c0a8592eb`'s run:
  4981/4976/0/2NI/3EF, VPI107, negative149, runtime15), JSON exit0 (unaffected,
  reused: 1873/0), UVM exit0 355/0/0 REAL DPI, NFA exit0 58/58, releases
  exit0 15/15 SMOKE_PASS (see U16), frontend exit0 all scenarios including
  new S12. Install restored; five of six frozen hashes unchanged, the sixth
  (`uvm_dpi.vpi`) changed as expected and is reframed as U15's new baseline
  (`evidence/campaign-20260908/u15/installed-frozen-sha256.json`).
- **Scope actually closed:** Native packed width/sign/four-state bits, exact
  real values, `string`-variable and string-literal values (including an
  embedded zero byte), valid transaction routing, and single evaluation of
  the value argument (verified: `single-eval-20260911.log`).
- **Bug found and fixed before closure:** the first committed encoder used
  `vpiType`/`vpiConstType` to decide when to retry with `vpiVectorVal`, which
  cannot distinguish a literal from a `.name()`/function-call/concatenation
  result -- all report the identical signature as a systf argument, yet only
  a literal supports `vpiVectorVal` (DD048). `.name()` is the single most
  common string field in real UVM `do_record` bodies, so the bug was on the
  primary path, not an edge case; corrected before any gate ran on it.
- **Remaining parent scope (DD038, still OPEN):** Complete declared schema,
  aggregates, object identity/cycles and deterministic default installation.
  No default-recorder installation in this increment; see U16 for the
  narrower, harness-scoped 1.1b/1.1c macro fix, which is deliberately kept
  separate from this native-capture scope.
- **Discovered, record-only:** DD048 (`__vpiVThrStrStack` has no
  `vpiVectorVal` path and reports `vpiSize` in a different unit than
  `__vpiStringConst`).
- **Evidence:** `evidence/campaign-20260908/u15/`.


### U16 — Legacy UVM release smoke compatibility (1.1b/1.1c)

- **Status:** CLOSED 2026-09-11. Semantic `90e95c339`.
- **Scope:** uvm-1.1b and uvm-1.1c guard `uvm_record_attribute` with
  `ifdef QUESTA/VCS/INCA` and no unguarded fallback branch (1.1d added one;
  these two omit it), so the macro is undefined on any simulator that is none
  of those three and `uvm_tlm2_generic_payload.svh` fails to parse -- a real
  omission in the archives, not a disagreement with them. `docs/uvm_frontend.md`
  states the normal `-uvm`/`--uvm-home` path defines no compatibility macros,
  and `-D` cannot express a function-like macro from the CLI at all, so the
  fix is a harness-only compat file
  (`scripts/uvm-release-compat/legacy_record_attribute.svh`) that
  `scripts/uvm_release_matrix.py` compiles ahead of a release's own
  `uvm_pkg.sv`, only for the two release ids a new `record_attribute_compat`
  manifest field names. It routes to U15's real, tested
  `$ivl_uvm_record_attribute`, not a no-op stub. No pinned archive edited, no
  vendor impersonated, no change to the normal path.
- **Result:** `scripts/uvm_release_matrix.py` reaches 15/15 SMOKE_PASS,
  `complete=true`/`baseline_valid=true`, including 1.1d's separate
  recording-lifecycle qualification
  (`evidence/campaign-20260908/u15/releases-full.log`, exit0). All 13
  previously passing releases are unaffected (gated on the manifest field).
- **Evidence:** `evidence/campaign-20260908/u15/releases-full.log`;
  `third_party/uvm-releases/results-xz9vnb6n/results.json`.


### L32 — VPI string literal vector extraction

- **Status:** CLOSED 2026-09-11 for the literal/parameter vpiVectorVal scope.
  Semantic `ab54351c3`; test oracle correction `fc90f1fa2`. The `swrite` endian
  probe relied on the old reversed literal order. `%u` of a literal now equals
  `%u` of the equivalent vector, as 5.9 and the format specifications clause
  (2017 21.2.1.2, 2023 21.2.1.1) require, so only the probe expectation changed.
  Gates, all with durable exit files: integrated exit0 4981/4976/0/2NI/3EF,
  VPI107, negative149, runtime15; JSON exit0 1873/0 with rows identical to U14;
  UVM exit0 REAL DPI 355/0/0 with rows identical; frontend exit0 all scenarios,
  install restored and six hashes match; NFA 58/58; releases unchanged 13
  SMOKE_PASS/2 COMPILE_FAIL. The string-parameter sibling path is verified in both
  editions. The TEMP subclass is reachable only from interactive `$stop`
  commands and is untested; the vlog95 swrite variant is not run. DD047 found.
- **Reducer:** Both editions return `"ABCD"` as0x44434241 instead of0x41424344;
  `"ABCDE"` also has reversed word placement. Shared loop additionally shifts
  signed bytes and initializes a word beyond the required allocation.
- **Scope:** Repair shared literal vector packing; preserve metadata and other
  conversions. IEEE5.9 and38.15; full typed recording remains open.
- **Evidence:** `evidence/campaign-20260908/u15/literal-vector-red.json` and
  `evidence/campaign-20260908/l32/`. Resume U15 after fullvalidation.

### L33 — Nested class-property VPI lvalue silently drops writes

- **Status:** CLOSED 2026-09-11. Selected from the DD046 fallback-inventory
  triage (`evidence/campaign-20260908/dd046/triage-20260911.md`, "Candidate 2,
  revised"). All required gates pass, durable exit files in
  `evidence/campaign-20260908/l33/`: integrated (legacy ivtest) exit0
  4981/4976/0/2NI/3EF, VPI107, negative149, runtime15/15 (a first run showed
  822 false failures from a stray orphaned `vvp_reg.pl` process racing the
  tracked run on the shared `ivtest/vsim` output file, confirmed by process
  inspection and a clean rerun -- not a real regression); JSON exit0 1873/0;
  UVM exit0 356/0/0 (baseline355 +1, the new permanent regression, both
  `plusargs_class_string_nested_test` and the existing direct-case
  `plusargs_class_string_test` PASS); NFA 58/58; releases unchanged 15/15
  SMOKE_PASS; frontend exit0 all S1-S12 scenarios including the new
  attribute-capture and recording scenarios from U15/U16. Install restored:
  `iverilog`/`ivl`/`uvm_dpi.vpi`/`uvm_legacy_recorder.svh` hashes unchanged
  from the U15 baseline; `vvp`/`vvp.tgt` changed, matching the four files this
  fix actually touched (`evidence/campaign-20260908/l33/installed-frozen-sha256.json`).
- **Symptom:** A `$value$plusargs`/similar VPI-lvalue write to a class string
  property reachable only through another class-typed property (e.g.
  `obj.inner.s`, IEEE1800 clause38.15 vpiStringVal/vpiVectorVal write path)
  silently discarded the value. `tgt-vvp/draw_vpi.c`'s `get_vpi_taskfunc_signal_arg`
  already emitted a working `&CPS<vSIG,pidx>` property-aware VPI handle for a
  DIRECT class-string-property base (`obj.s`, Phase51/U15), but its own comment
  said "Only handle the simple case (direct signal base, not nested)" -- a
  nested chain fell back to `draw_eval_string`, an rvalue-only stack temporary
  whose `vpi_put_value` result is discarded once the systf call returns. No
  error was printed; the plusarg's own matched/not-matched status was
  unaffected, so this was a genuinely silent data-loss path.
- **Root cause:** `ivl_expr_signal()` on an `IVL_EX_PROPERTY` node is a
  shortcut elaboration takes only for a single, non-chained property access.
  Once a property access is itself used as the BASE of a further property
  access, elaboration builds the intermediate node through the generic
  base-expression path (`ivl_expr_oper2()`) instead, even when that base is
  in fact a plain signal -- so `expr_signal_base_()`, and the old fast-path's
  `!ivl_expr_signal(expr)` guard, saw a null signal and bailed to the
  rvalue-only fallback for any chain longer than one hop.
- **Fix:** `tgt-vvp/draw_vpi.c` gained `collect_property_chain_()`, which walks
  an arbitrary-depth string-property chain down to its root signal (stopping
  at either the direct-signal shortcut or a plain-signal base), rejecting any
  hop that is array-indexed (`ivl_expr_oper1()` set) as out of scope. The
  matched chain now emits a variable-arity `&CPS<vSIG_0,idx0,idx1,...>` (was
  fixed two-field). `vvp/parse.y`'s `K_CPS` production now takes the existing
  `numbers` list nonterminal instead of one `T_NUMBER` (zero new grammar
  conflicts -- bison table diffed against the unmodified baseline, only the
  touched production and its own states differ). `vvp/vpi_cobject.cc`'s
  `__vpiClassPropertyStringVar` now holds a property-index PATH rather than a
  single index: every hop but the last is walked via `vvp_cobject::get_object()`
  at each access (the intermediate class handle can change at runtime), and a
  null handle mid-chain on a WRITE reports loudly (`vvp error: class property
  write through a null intermediate class handle...`, matching the existing
  virtual-interface-write-rejection convention) rather than dropping silently
  -- the exact failure mode this blocker exists to remove, not reintroduced
  one level up. Reads through a null intermediate stay silently empty,
  matching this class's pre-existing convention for "no object at all".
- **Scope (deliberately bounded, per AGENTS.md "do not claim a parent feature
  complete after fixing one subcase"):** STRING class properties only.
  Integral (vec4/`CPV`) nested class properties have the identical gap
  (`get_vpi_taskfunc_signal_arg`'s CPV branch still requires a direct signal
  base) and are explicitly NOT fixed here -- recorded as follow-on work, not
  silently left ambiguous. Array-indexed hops anywhere in a chain (`arr[i].s`,
  `obj.arr[i].s`) and virtual/polymorphic dispatch are out of scope and still
  fall back to the rvalue-only path (unchanged pre-existing behavior, not a
  regression). Verified: 1-level (`obj.inner.s`), 2-level/3-hop
  (`obj.mid.leaf.s`), and the null-intermediate-handle write all behave as
  designed; array-indexed hop falls back without crashing.
- **Reducers:** `evidence/campaign-20260908/dd046/c2.sv` (direct case, must
  keep working), `c3.sv` (the original 1-level nested repro), `c4_deep.sv`
  (3-level nesting, confirms the recursion generalizes beyond 1 hop),
  `c5_null.sv` (write through a null intermediate handle -- must error
  loudly, not drop silently), `c6_arrhop.sv` (array-indexed hop -- must fall
  back to the rvalue-only path without crashing, confirmed out of scope).
- **Permanent regression:** `tests/plusargs_class_string_nested_test.sv`
  (new), registered in `.github/uvm_test.sh`'s `plusargs_for()`. Sibling of
  the existing Phase51 `tests/plusargs_class_string_test.sv`, which covers the
  direct (non-nested) case and must keep passing unchanged.
- **Validation:** full required sequence passed (integrated/JSON/UVM/NFA/
  releases/frontend-last); see the Status line above for exact counts and
  `evidence/campaign-20260908/l33/` for durable exit files.
- **Evidence:** `evidence/campaign-20260908/l33/`,
  `evidence/campaign-20260908/dd046/triage-20260911.md`.
- **Addendum (found during L34):** `collect_property_chain_()` (shared by
  this entry's string path and L34's integral path) had a latent gap this
  entry's own gates never exercised: a property access whose base is a
  WORD-INDEXED array of class handles (`arr[1].s`, not merely a chain of
  named properties) carries its index via `ivl_expr_oper1()` on the
  `IVL_EX_SIGNAL`/`IVL_EX_ARRAY` base node, which the helper ignored,
  emitting a label for the wrong (nonexistent) functor. No ivtest test
  exercised "array-of-objects then `.string_property`" at L33's close, so
  this passed unnoticed at the time; L34's gate sweep caught the identical
  gap via an integer-property test and the fix (reject an array-indexed
  base, same as an array-indexed property hop) is in the shared helper, so
  it closes this gap for the string path too. Reverified:
  `evidence/campaign-20260908/dd046/c13_arr_of_obj_str.sv`.

### L34 — Nested class-property VPI lvalue silently drops writes (integral sibling of L33)

- **Status:** CLOSED 2026-09-11. The integral (vec4/CPV) counterpart of
  L33, explicitly named as an un-fixed follow-on in that entry rather than
  left ambiguous. All required gates pass, durable exit files in
  `evidence/campaign-20260908/l34/`: integrated exit0 4981/4976/0/2NI/3EF,
  VPI107, negative149, runtime15/15; JSON exit0 1873/0; UVM exit0 357/0/0
  (356 baseline +1, all four plusargs class-property tests -- direct and
  nested, string and integral -- PASS); NFA 58/58; releases unchanged
  15/15 SMOKE_PASS; frontend exit0 all S1-S12. Install restored:
  `iverilog`/`ivl`/`uvm_dpi.vpi`/`uvm_legacy_recorder.svh` hashes unchanged
  from the L33 baseline; `vvp`/`vvp.tgt` changed, matching the four files
  this fix touched (same four files as L33) --
  `evidence/campaign-20260908/l34/installed-frozen-sha256.json`. A real
  regression (not a race-condition false positive) was found and fixed by
  the ivtest gate mid-pass -- see the dedicated bullet below.
- **Symptom:** Identical to L33 but for `int`/`bit`/`logic`-typed class
  properties: `$value$plusargs("N=%d", obj.inner.n)` silently dropped the
  write when `n` is reached through another class-typed property
  (`obj.inner.n`). The direct case (`obj.n`) already worked via
  `&CPV<vSIG,pidx,width,signed>` (M14/prior session); a nested chain fell
  back to a discarded vec4 stack temporary, same failure shape as L33
  before its fix.
- **Root cause:** Identical mechanism to L33 -- `get_vpi_taskfunc_signal_arg`'s
  old direct-only CPV check required `ivl_expr_signal(expr)` non-null on the
  property node itself, which is null for any nested property chain (see
  L33's root-cause writeup); any chain longer than one hop fell through to
  the rvalue-only path with no error.
- **Fix:** Reused L33's `collect_property_chain_()` unchanged (it is
  already type-agnostic about the leaf property's value type) from a new
  integral-specific call site placed at the same point in
  `get_vpi_taskfunc_signal_arg` as L33's string call site -- before the
  `expr_signal_base_()`-based `if (!sig) return 0` bailout that ate the
  chain for the same reason L33 hit it. The old direct-only CPV block
  became fully dead code once the chain-based check subsumed it (the
  chain collector's base case handles the direct/non-nested case
  identically to the old check) and was deleted rather than left stale.
  `vvp/parse.y`'s `K_CPV` production now takes `numbers` for the chain, but
  -- unlike `K_CPS` -- the chain had to move to the END of the production
  (`&CPV<vSIG_0,width,signed,idx0,idx1,...>`, was
  `&CPV<vSIG_0,pidx,width,signed>`) because CPV has two trailing fixed
  fields (width, signedness) after the property index; putting `numbers`
  before them would be genuinely LALR(1) ambiguous (the parser cannot
  decide, on the next `T_NUMBER`, whether it continues the chain or starts
  the fixed fields). `numbers` followed only by `'>'` is unambiguous, same
  as `K_CPS`. Verified zero new grammar conflicts the same way as L33:
  bison's full verbose table diffed against the (already-verified-clean)
  L33 baseline shows only the `K_CPV` production's own states differing.
  `vvp/vpi_cobject.cc`'s `__vpiClassPropertyVecVar` now holds a
  property-index path exactly like `__vpiClassPropertyStringVar`; a null
  intermediate handle on a write reports loudly via the same
  `report_null_property_container_write_()` L33 added, not a new message.
- **Scope (same boundary as L33):** Integral (`bit`/`logic`/`int`, i.e.
  `IVL_VT_LOGIC`/`IVL_VT_BOOL`) class properties only. `real`-typed nested
  properties, array-indexed hops in a chain, and virtual/polymorphic
  dispatch remain out of scope and fall back to the pre-existing
  rvalue-only path (unchanged, not a regression). Verified: 1-level
  (`obj.inner.n`), 3-level/3-hop (`obj.mid.leaf.n`), and the
  null-intermediate-handle write all behave as designed; array-indexed hop
  falls back without crashing.
- **A second, genuine regression was found and fixed by the ivtest gate
  before this closed** (not the L33 race-condition false positive): the
  first committed L34 change made `collect_property_chain_()`'s
  `IVL_EX_SIGNAL`/`IVL_EX_ARRAY` base-case branch accept the base
  unconditionally, but a word-indexed array-of-class-handles base (e.g.
  `arr[1].id`, `fixed[0].id` -- an array element, not a chain of named
  properties) carries its index via `ivl_expr_oper1()` on that base node.
  Ignoring it and hardcoding the emitted label's word suffix to the
  scalar case produced a label matching no real functor: vvp printed
  "unresolved functor stub" and the read came back `X` instead of the real
  value. Caught by two vendored ivtest tests
  (`sv_array_port_object_event`, `sv_cast_container_task_failure`),
  reduced to `evidence/campaign-20260908/dd046/c12_arr_of_obj.sv`, and
  fixed by rejecting an array-indexed base the same way an array-indexed
  *property* hop was already rejected -- fall back to the safe rvalue-only
  path, which resolves the word correctly. This bug lived in the shared
  helper, so it equally affected L33's string path (never caught there,
  since no ivtest test combines an object array with a string property);
  see the addendum on L33 above. Both ivtest regressions reverified
  passing against gold after the fix.
- **Reducers:** `evidence/campaign-20260908/dd046/c7_int_nested.sv` (direct
  bug reproduction), `c8_direct.sv` (direct case, must keep working),
  `c9_deep_int.sv` (3-level nesting), `c10_null_int.sv` (null-intermediate
  write), `c11_arrhop_int.sv` (array-indexed property hop, out of scope),
  `c12_arr_of_obj.sv` (array-indexed SIGNAL base, the second regression
  above), `c13_arr_of_obj_str.sv` (string analog of c12, confirming the
  shared-helper fix also closes L33's latent gap).
- **Permanent regression:** `tests/plusargs_class_integral_nested_test.sv`
  (new), registered in `.github/uvm_test.sh`'s `plusargs_for()`. Sibling of
  the existing `tests/plusargs_class_integral_test.sv` (direct case), which
  must keep passing unchanged. The array-of-objects regression itself is
  already covered by two existing vendored ivtest tests
  (`sv_array_port_object_event`, `sv_cast_container_task_failure`); no new
  permanent test needed beyond keeping them in the required ivtest gate.
- **Validation:** full required sequence passed (integrated/JSON/UVM/NFA/
  releases/frontend-last); see the Status line above for exact counts and
  `evidence/campaign-20260908/l34/` for durable exit files.
- **Evidence:** `evidence/campaign-20260908/l34/`.

### L35 — Assigning a string value to a real target silently substituted 0.0

- **Status:** CLOSED 2026-09-11. Found via DD046's curated-table re-triage
  (the "Lost expression typing" row), which had been closed the same day
  as "empirically unreached across ~5300 tests" -- but per an advisor
  review, a probe that never fires and a probe that's never reached look
  identical, so a hand-written sanity reducer was built to confirm the
  instrumentation actually could fire before trusting that negative
  result. It fired immediately on the most ordinary possible construct
  (`real r; string s; ...; r = s;`), which is what DD046's table entry
  had missed: this branch is reachable by completely mainstream code, not
  only by exotic unresolved-parameterized-method paths. All six required
  gates pass at the exact pre-existing baseline plus the one new
  permanent test: integrated exit0 4982/4977/0/2NI/3EF (4981/4976 baseline
  +1 new CE test), JSON exit0 1873/0 (unaffected -- new test lives only in
  the legacy ivtest list), UVM exit0 357/0/0, NFA 58/58, releases 15/15
  SMOKE_PASS, frontend exit0 all S1-S12. Install restored: only
  `local-install/lib/ivl/ivl` (the frontend binary) changed vs the L34
  baseline -- `iverilog`/`vvp`/`vvp.tgt`/`uvm_dpi.vpi`/
  `uvm_legacy_recorder.svh` hashes unchanged, exactly as expected for a
  pure elaboration-time fix touching no codegen/runtime path --
  `evidence/campaign-20260908/l35/installed-frozen-sha256.json`.
- **Symptom:** `real r; string s; s = "3.5"; r = s;` compiled clean with
  no diagnostic and always read `r == 0.0` at runtime, silently
  discarding the string value (and any side effects already evaluated
  computing it).
- **Root cause:** `netmisc.cc`'s `elab_and_eval` (both overloads -- the
  `PExpr*`/`ivl_variable_type_t cast_type` form and the `ivl_type_t
  lv_net_type` form) has a compile-progress fallback, added to handle
  genuinely unresolved/generic parameterized-method-argument typing,
  that stubs ANY expression whose elaborated type doesn't match a
  STRING or REAL `cast_type` to an empty string / `0.0` / `null` rather
  than erroring. The sibling BOOL/LOGIC/vectorable branch right next to
  it already excludes a well-typed STRING source (`&&
  tmp->expr_type() != IVL_VT_STRING`) specifically because R30 found
  this exact defect shape for vector targets (`reg [127:0] b; b = str;`
  silently storing zero) and fixed it by letting a well-typed string
  fall through to the real cast machinery instead of being stubbed. The
  REAL-target branch a few lines above never got the same exclusion --
  a well-typed `IVL_VT_STRING` source unconditionally became `0.0`,
  reproducing R30's exact defect class one branch over, missed because
  R30's fix and the comment explaining it are physically adjacent to
  but not covering this branch.
- **Why a stub AND a fallthrough are both wrong here, so this is a hard
  error and not a repeat of R30's fix:** unlike the vector-target case
  (where falling through to `cast_to_int4`/`cast_to_int2` correctly
  packs the string per IEEE 1800-2017/2023 6.16's defined
  string-to-integral conversion), there is no defined string-to-real
  conversion in the LRM at all -- 6.16 enumerates only string<->integral
  and string<->string implicit conversions. Tracing what falling through
  to the existing `cast_to_real()`/`NetECast('r',...)` path would
  actually do confirmed it is not a safe alternative either:
  `tgt-vvp/eval_real.c`'s `draw_unary_real()` handles opcode `'r'` by
  evaluating the sub-expression as a vec4 bit pattern
  (`draw_eval_vec4`) and converting that pattern to a real via
  `%cvt/rv` -- correct for an integral source, but for a string source
  it would reinterpret the string's packed ASCII bytes as a (typically
  huge) unsigned integer and convert that number to a real, which is
  not a sensible "value of the string" under any defined semantics
  either. Neither existing behavior (silent 0.0) nor the naive
  alternative (silent garbage bit-pattern reinterpretation) is
  spec-correct, so per the precedent already set for a class handle
  into a non-class target (R32 finding A, 8.4) and a well-typed
  aggregate into a scalar (R32 finding B, 7.2.2/7.10), this is a hard
  compile error, not a stub of any kind.
- **Fix:** In both `elab_and_eval` overloads, the `cast_type ==
  IVL_VT_REAL` branch now checks `tmp->expr_type() == IVL_VT_STRING`
  first and, if true, reports `error: A string value has no implicit
  conversion to real (IEEE 1800-2017/2023 6.16); an explicit conversion
  such as string::atoreal() is required.` and fails elaboration instead
  of stubbing. A genuinely unresolved/generic (non-STRING) `tmp` type
  still gets the pre-existing `0.0` compile-progress placeholder --
  this fix narrows the branch to stop swallowing a WELL-TYPED string,
  it does not touch the still-open generic/parameterized-method case
  the branch was originally written for.
- **Scope:** Implicit real-target assignment (`real r; r = <string
  expr>;`, and equivalently through a task/function real-typed formal or
  a class real-typed property target reached via the `ivl_type_t`
  overload) only. `string::atoreal()` (explicit method call), integral-
  to-real, and real-to-real all continue to work exactly as before --
  verified with dedicated reducers. Not investigated: the second
  overload's sibling BOOL/LOGIC/vectorable branch
  (`netmisc.cc:2352-2358`) has no `tmp->expr_type() != IVL_VT_STRING`
  exclusion either (unlike the first overload's equivalent branch,
  which does) -- this may be the same R30-class gap recurring a third
  time in a different context, but was not reproduced or fixed this
  pass; flagged for a future increment rather than fixed speculatively.
- **Reducers:** `evidence/campaign-20260908/dd046/c22_real_string.sv`
  (the defect, confirms the hard error), `c22b_atoreal_ok.sv`
  (`string::atoreal()` still works), `c22c_int_to_real_ok.sv`
  (int-to-real still works), `c22d_real_to_real_ok.sv` (real-to-real
  still works).
- **Permanent regression:** `ivtest/ivltests/sv_real_string_assign_fail.v`
  (new, `CE` type), registered in `ivtest/regress-sv.list` alongside the
  existing `sv_class_new_fail1` (the same "illegal implicit conversion
  now hard-errors" pattern, for class handles rather than strings).
- **Validation:** full required sequence passed (integrated/JSON/UVM/NFA/
  releases/frontend-last); see the Status line above for exact counts and
  `evidence/campaign-20260908/l35/` for durable exit files.
- **Evidence:** `evidence/campaign-20260908/l35/`.

### L36 — Fixed-array locator methods rejected legal non-integral/non-zero-base arrays

- **Status:** CLOSED 2026-09-11. Found by directly re-auditing every DD046
  "loud diagnostic" disposition against a stricter bar per user challenge:
  does the diagnostic fire ONLY on illegal SystemVerilog? The Array-locator
  row's rejection did not -- it fired on legal code.
- **Symptom:** `find`/`find_index`/`find_first`/etc. on a fixed-size
  (non-dynamic, non-queue) unpacked array rejected with `sorry: ... on a
  fixed-size array of this element type is not yet implemented` whenever
  the element type was not BOOL/LOGIC, or whenever the array's declared
  range was not zero-based/ascending -- e.g. `string values[1:0];
  values.find_last with (...)` or `int values[5:3]; ...find_last_index...`.
  IEEE 1800-2017/2023 7.12.1: "Array locator methods operate on any
  unpacked array" -- no restriction to integral elements or declared base.
- **Root cause:** `elab_expr.cc`'s array-locator dispatch had two
  independent, artificially narrow gates that `make_array_unique_expr_`
  (the sibling helper used elsewhere for the same materialize-into-a-
  `netdarray_t`-temp pattern) does not have: (1) `make_queue_locator_with_expr_`'s
  `fixed_property` computation excluded any *direct signal* source
  (`!dynamic_cast<NetESignal*>(queue_expr)`), and (2) a separate check
  rejected any element type other than BOOL/LOGIC and any non-zero-based
  declared dimension outright.
- **Fix:** Removed the `NetESignal` carve-out so `fixed_property` is simply
  `fixed_type` (matching `make_array_unique_expr_`'s unconditional
  materialization), and replaced the element-type/base-range gate with a
  single check on `base_type()` allowing BOOL, LOGIC, REAL, STRING, and
  CLASS (the materialize-to-`netdarray_t` path already supports every one
  of these; only genuinely unsupported element categories still `sorry`).
  The declared-base restriction is gone entirely -- the loop already
  carries a separate declared index for `item.index`/`*_index` results,
  computed generically for any base, so nothing else needed to change.
- **Scope:** Fixed-array (direct-signal and class-property) locator
  methods only. Multidimensional fixed arrays remain a genuine, still-loud
  `sorry` (iterating subarrays is unimplemented) -- confirmed still correct
  and unaffected. Also repaired two stale ivtest negative tests whose own
  comments already admitted the rejected forms were legal SV.
- **Reducers:** `evidence/campaign-20260908/l36/` (nonzero/descending base,
  string/real elements, paren-less syntax, multidim-still-rejected).
- **Permanent regression:** `ivtest/ivltests/sv_locator_fixed_nonintegral.v`
  (new, positive), `sv_array_find_last_fixed_base.v` (renamed/rewritten
  from the former `..._fail.v` negative test, now a positive test),
  `sv_array_find_last_fixed_shape_fail.v` (rewritten to drop the now-fixed
  case, keeping only the still-correct multidim rejection).
- **Validation:** see the combined L36-L40 validation note at the end of
  this run of entries.
- **Evidence:** `evidence/campaign-20260908/l36/`.

### L37 — Bit-stream cast to an unpacked struct crashed the compiler

- **Status:** CLOSED 2026-09-11. Found while auditing the "Casts" DD046
  row for the same "loud diagnostic on legal input" question that
  produced L36 -- this one turned out worse: not a wrong rejection, an
  outright crash.
- **Symptom:** `s_t'(v)` (an explicit bit-stream cast of a packed vector to
  an unpacked-struct type, legal per IEEE 1800-2017/2023 6.24.3) printed a
  warning and then crashed: `Assertion failed: (net), function
  ivl_expr_value, file t-dll-api.cc, line 1059`.
- **Root cause:** `PECastType::elaborate_expr`'s final fallback for a
  non-packed cast target unconditionally did `return sub;`, handing back a
  vector-shaped expression where downstream codegen (`t-dll-api.cc`'s
  `ivl_expr_value`) expects a struct-shaped one; the mismatch produced a
  null child expression that the codegen's `assert(net)` caught as a
  crash rather than a clean diagnostic.
- **Fix:** Per advisor review, full bit-stream-casting support (general
  packed<->unpacked/struct/class conversion per 6.24.3) is a feature, not
  a fallback fix, and was explicitly scoped out. Instead, the crash-prone
  `return sub;` for a non-packed target now reports `sorry: bit-stream
  cast to '<type>' is not yet implemented (IEEE 1800-2017/2023 6.24.3)`
  and fails elaboration cleanly -- converting an unbounded crash into a
  bounded, honest "not yet implemented" the same way every other
  feature-sized gap in this codebase is represented.
- **Scope:** Non-packed-target bit-stream casts only. Packed-target casts
  (the already-correct, already-common case -- e.g. casting a struct or
  array to a packed vector) are untouched and verified unaffected.
- **Permanent regression:** `ivtest/ivltests/sv_bitstream_cast_unpacked_struct_fail.v`
  (new, `CE`, the crash -> clean-sorry conversion) and
  `sv_bitstream_cast_packed_struct.v` (new, positive, confirms the
  packed-target path is unaffected).
- **Evidence:** `evidence/campaign-20260908/l37/`.

### L38 — `inside {}` silently forced membership to 0 for a queue-valued (non-property, non-plain-signal) expression

- **Status:** CLOSED 2026-09-11.
- **Symptom:** `x inside {f()}` where `f()` returns a QUEUE (not a plain
  signal or class property) silently evaluated to `0` regardless of the
  actual contents, with no diagnostic at all.
- **Root cause:** `tgt-vvp/eval_vec4.c`'s inside-operator object-stack
  dispatch arm named both "Queue/darray" in its own comment but its `if`
  condition only tested `ivl_expr_value(arr_arg) == IVL_VT_DARRAY`, never
  `IVL_VT_QUEUE` -- a straightforward missing-enum-value oversight, not a
  design gap (the plain-signal and class-property paths, and the DARRAY
  case of this exact arm, already worked correctly).
- **Fix:** Added the missing `|| ivl_expr_value(arr_arg) == IVL_VT_QUEUE`
  to the existing condition.
- **Permanent regression:** `ivtest/ivltests/sv_inside_queue_expr.v` (new,
  positive: function-returning-queue and function-returning-darray in
  `inside{}`).
- **Evidence:** `evidence/campaign-20260908/l38/`.

### L39 — Chained container-index then string byte-select on a class property rejected as unsupported

- **Status:** CLOSED 2026-09-11.
- **Symptom:** `obj.q[0][1]` where `obj.q` is a class-property `string
  q[$]` (a queue-element select followed by a byte/char select) hit
  `sorry: this index does not select a queue or associative-array
  class-property value`, even though both a bare `string_var[1]` and a
  class-property queue-of-queues `obj.q[0][0]` already worked
  independently via the identical `NetESelect` shape.
- **Root cause:** `apply_trailing_container_indices_` (the shared loop
  walking chained bracket-indices on a class-property container
  expression) dispatched only on `netvector_t` (packed select) and
  `netarray_t` (container element select) for `cur_type`; a `netstring_t`
  intermediate type (the queue's element, after the first index) fell
  through to the generic "sorry" reject with no string-select branch.
- **Fix:** Added a `netstring_t` branch performing a plain string
  byte-select via `NetESelect(cur_expr, index_expr, 8)`, reusing the
  existing `elab_assoc_index` helper for index elaboration -- mirroring
  the plain-string-select code path already used elsewhere.
- **Permanent regression:** `ivtest/ivltests/sv_property_queue_string_charsel.v`
  (new, positive).
- **Evidence:** `evidence/campaign-20260908/l39/`.

### L40 — A class-handle value read through a specialized parameterized class's own type parameter silently degraded to an empty string with zero diagnostic

- **Status:** CLOSED 2026-09-11. First attempt REVERTED the same session
  when the UVM gate caught a real regression; root-caused and re-fixed,
  correctly this time, per explicit user direction to fix it completely
  rather than leave it open. Found while auditing the STRING/CLASS
  `netmisc.cc` stub candidates (part of the user-directed "fix the other
  8" sweep) for a genuine unresolved-generic reproducer.
- **Symptom:** `container #(type T=int)` specialized as `container#(obj_c)`
  (a real class type), whose own method does `T val; string s; s = val;`,
  silently produces `s == ""` at runtime with **no diagnostic whatsoever**
  -- worse than the plain module-scope case (already a hard error per an
  earlier fix in this same function), since ordinary UVM/OOP code lives
  almost entirely inside class methods.
- **Root cause (confirmed):** `netmisc.cc`'s class-handle-rvalue guard
  computes `class_rval_degrade_ok = in_class_scope || cast_type==IVL_VT_LOGIC
  || <PENull>`, where `in_class_scope` is a COARSE check -- true for any
  code textually inside ANY class body. The guard's own comment documents
  exactly two intended exemptions: (a) a genuinely dead
  generic-template-seed elaboration pass (IEEE 1800-2017/2023 8.25: "a
  generic class is not a type"), for which the sibling `is_class_new`
  exemption already uses the PRECISE `in_unspecialized_param_class` check;
  and (b) a forward-referenced class name that collapses to implicit
  4-state LOGIC (`cast_type==IVL_VT_LOGIC`, the "UVM printer globals"
  case). `class_rval_degrade_ok` uses the coarse `in_class_scope` where it
  could use the precise (a) check, so a real specialization's
  class-handle-to-string assignment silently degrades instead of
  hard-erroring.
- **First attempt, REVERTED:** narrowed `class_rval_degrade_ok` (and the
  paired warning-suppression condition) to use `in_unspecialized_param_class`
  instead of `in_class_scope` wholesale, mirroring `is_class_new`. This
  correctly hard-errored the real-specialization reducer AND correctly
  stayed silent for a class whose own declared default type parameter is
  itself a class (`container #(type T = base_c)`, specialized everywhere
  in the design only with `int`) -- both directions of the predicate this
  fix targets were verified. **But the six-gate sweep's UVM/ivtest run
  caught a THIRD, undocumented scenario the coarse `in_class_scope` was
  also covering**: `uvm_vreg::allocate()`'s `this.mem = mam.get_memory();`
  -- an ordinary, ZERO-generics, class-to-class (`uvm_mem`-to-`uvm_mem`)
  property assignment inside a plain (non-parameterized) class method --
  newly hard-errored with "class handle cannot be assigned to a non-class
  target" after the wholesale narrowing.
- **Tracing the third scenario:** temporary `IVL_L40_DEBUG`-gated
  instrumentation at the guard printed `cast_type` and the enclosing scope
  for every entry; against `sv_package_lazy_subroutine_scope.v -uvm` (an
  existing permanent ivtest case that happens to compile enough of the UVM
  register model to reach `uvm_vreg.svh:736`), it showed `cast_type=3`
  (`IVL_VT_BOOL`) for that exact assignment -- NOT `IVL_VT_LOGIC`. Reading
  `uvm_vreg.svh`/`uvm_mem_mam.svh` confirmed why: they forward-declare each
  other (`typedef class uvm_mem_mam;` / `typedef class uvm_mem;`), and that
  circular forward reference collapses `this.mem`'s target to a 2-state
  placeholder -- the SAME "forward-referenced class collapses to an
  implicit type" mechanism case (b) already documents for LOGIC, just
  landing on the 2-state atom instead of the 4-state one this time.
  `cast_type == IVL_VT_LOGIC` doesn't match `IVL_VT_BOOL`, so only the
  broad `in_class_scope` was covering this variant.
- **Fix (correct, landed):** rather than widen the `cast_type` checks
  (which would touch every class-scope degrade, not just the one L40
  targets) or reintroduce the wholesale `in_unspecialized_param_class`
  swap, added a narrow, additional carve-out: `in_real_specialized_param_class`
  (true exactly when the enclosing scope is a parameterized class AND a
  REAL, non-seed-derived specialization -- the logical complement of the
  existing `in_unspecialized_param_class` within a parameterized class's
  body). `class_rval_degrade_ok` becomes `(in_class_scope &&
  !in_real_specialized_param_class) || cast_type==IVL_VT_LOGIC ||
  <PENull>` -- `in_class_scope`'s broad permissiveness is otherwise
  completely untouched (including the BOOL forward-ref collapse case),
  and only the one case L40 targets (a real specialization) is carved out
  to hard-error. Verified all three: the real-specialization reducer now
  hard-errors, the dead-template-seed reducer still compiles silently, and
  `uvm_vreg.svh:736` (via `sv_package_lazy_subroutine_scope.v -uvm`)
  compiles clean again.
- **A separate, pre-existing, unrelated defect surfaced while building the
  "must stay silent" reducer, not part of this fix:** reading an ordinary
  INTEGRAL class property (no generics involved at all) back as a string
  from inside its own class method -- `class c; int val; function string
  f(); string s; s = val; return s; endfunction endclass` -- warns
  `class_property_t::get_string on unsupported property type ...
  returning empty string` and produces `""`, on a plain non-parameterized
  class with no relation to L40's guard (confirmed: this path is
  `IVL_VT_LOGIC`, never enters the `IVL_VT_CLASS` guard at all). Recorded
  in `DISCOVERED_DEBT.md` as a fresh, unfixed, out-of-scope finding
  (anchor `vvp/class_type.cc:536`).
- **Permanent regression:** `ivtest/ivltests/sv_class_handle_string_specialized_fail.v`
  (new, `CE`, the real-specialization hard error) and
  `sv_class_handle_string_seed_ok.v` (new, positive, the dead-seed
  exemption). The forward-ref-collapse (BOOL) case is guarded by the
  pre-existing `sv_package_lazy_subroutine_scope.v -uvm` (already in
  `regress-sv.list`) rather than a new dedicated reducer -- two attempts
  at a minimal, non-UVM standalone reproduction of the circular
  forward-declaration collapse did not reproduce it (kept as negative
  evidence in `evidence/campaign-20260908/l40/l40_uvmvreg_min.sv` and
  `l40_forward_ref_min.sv`); the real UVM register-model source is the
  only confirmed trigger found.
- **Evidence:** `evidence/campaign-20260908/l40/`.

### L36-L40 combined validation

- **Validation:** all six required gates run together over the combined
  L36+L37+L38+L39+L40 changeset (elab_expr.cc, tgt-vvp/eval_vec4.c,
  netmisc.cc, plus 9 new permanent ivtest cases): integrated ivtest,
  JSON/VVP, UVM, NFA dual-run, UVM release matrix, frontend (alone/last).
  Final counts: integrated ivtest 4989/4984/0F/2NI/3EF, JSON/VVP 1873/0,
  UVM 357/0/0, NFA dual-run 58/58, UVM release matrix 15/15 SMOKE_PASS
  (all 15, including 1.0p1 -- restored by L37's follow-up class-cast
  fix), frontend all S1-S12. Merged as PR #277 (2026-09-12), all 6 CI
  platforms green (macOS, Ubuntu 22.04/24.04, MINGW64, UCRT64, CLANG64).
  See `evidence/campaign-20260908/l36/`...`l40/` for reducers and
  `installed-frozen-sha256.json` for the post-install binary hash diff.

### L41 — Class-body `import` statement misdiagnosed on error recovery

- **Status:** CLOSED 2026-09-13. Found while rebaselining OpenTitan after
  PR #277 -- re-verifying the original goal file's "parameterized-class
  inheritance blocking `ac_range_check_env_cov`" priority item against
  fresh census data.
- **Symptom:** an `import pkg::*;` statement written directly inside a
  class body (illegal per IEEE 1800-2017/2023 A.1.8/A.2.1.3, footnote:
  "It shall be illegal to have an import statement directly within a
  class scope" -- confirmed independently by Slang, `error: package
  import not allowed in class declaration`) was already correctly
  rejected by Icarus, but only via bison's generic syntax-error recovery
  on the bare `import` keyword: a bare `syntax error` + `Invalid class
  item.`, after which recovery resynchronizes mid-declaration and emits
  several misleading follow-on errors (e.g. `<pkg> doesn't name a type`)
  that blame later, unrelated lines instead of naming the actual illegal
  construct. This produced a real misdiagnosis in the field: the original
  2026-08-26 OpenTitan baseline session mischaracterized this exact
  construct in `ac_range_check_env_cov.sv` as "parameterized-class
  inheritance" being unimplemented -- a defect that never existed. (This
  specific misdiagnosis was already caught and corrected by an earlier
  session, recorded as memory `class-body-import-is-illegal`; L41 is the
  follow-through fix for the diagnostic-quality half of that finding.)
- **Root cause:** `parse.y`'s `class_item` production has no
  `package_import_declaration` alternative, so a bare `K_import` directly
  in a class body cannot be matched by any `class_item` alternative and
  falls straight to the generic `error ';'` / `error ';'` (with an
  `IDENTIFIER error ';'` variant that produces the misleading "doesn't
  name a type" text) recovery rules at the bottom of that production.
- **Fix:** Added `package_import_declaration` as a `class_item`
  alternative (parse.y) so the construct parses successfully and reaches
  `pform_package_import()` (pform_package.cc) instead of derailing.
  `pform_package_import()` now checks `dynamic_cast<const PClass*>(pform_peek_scope())`
  and, when the immediate enclosing scope IS the class body itself (not a
  method's own function/task scope nested inside it -- `PClass` is a
  `LexicalScope` via `PScopeExtra`/`PScope`; a method's scope is a
  different, non-`PClass` `LexicalScope` even though its parent is one),
  reports one focused, citation-bearing error and refuses the import
  (does not add its symbols to the scope) instead of proceeding. Verified
  zero new bison grammar conflicts (563 shift/reduce, 1122 reduce/reduce,
  identical totals before and after this change).
- **Verified against real OpenTitan source:** `ac_range_check_env_cov.sv:12`
  hard-error-count dropped from 72 to 69 (line 12 is now the single clean
  diagnostic; the line-19 cascade was already present in the ORIGINAL,
  unfixed trace too -- confirmed separate and pre-existing, not something
  this fix left unaddressed). `pwrmgr_base_vseq.sv:21` (3 tops) dropped
  from 4 to 3 hard errors each (now one clean diagnostic; the remaining 2
  errors are a wholly unrelated duplicate-module-declaration issue in a
  different file, `pwrmgr_csr_assert_fpv.sv`).
- **An unverified claim caught and corrected in-flight:** the first draft
  of this fix's comments asserted "an import inside a method body is
  unaffected, still legal" without testing it. It doesn't hold: `import
  pkg::*;` written ANYWHERE inside an ordinary (non-class) function or
  task body already fails with a plain syntax error in Icarus today,
  completely independent of this fix or of classes at all. Corrected the
  comments before closing; recorded as `DISCOVERED_DEBT.md` DD-018, a
  separate, unfixed, untriaged finding -- not investigated further here.
- **Permanent regression:** `ivtest/ivltests/sv_class_body_import_fail.v`
  (new, `CE`).
- **Validation:** integrated ivtest 4990/4985/0F/2NI/3EF, JSON/VVP 1873/0,
  UVM 357/0/0, NFA dual-run 58/58, UVM release matrix 15/15 SMOKE_PASS,
  frontend all S1-S12.
- **Evidence:** `evidence/campaign-20260908/l41/`.

### L42 — Integral class-property read/written as a string used the wrong conversion (or none)

- **Status:** CLOSED 2026-09-13. Found incidentally while building an
  L40 "must stay silent" reducer, deferred as feature-sized at the time;
  picked up as the next Phase-B implementation-campaign item.
- **Symptom:** reading an ordinary integral class property (`int`, `byte`,
  `shortint`, `longint`, `bit [N:0]`, `logic [N:0]`) back as a `string`
  from inside its own class method -- `class c; int val; function string
  f(); string s; s = val; return s; endfunction endclass` -- warned
  `class_property_t::get_string on unsupported property type ...
  returning empty string` and produced `""`, instead of the correct IEEE
  1800-2017/2023 6.16 packed-byte value (`42` -> `"*"`, the same
  conversion a plain, non-property `int` variable already got correctly:
  confirmed `int x; string s; x=42; s=x;` already produced `"*"` before
  this fix, len 1, leading zero bytes dropped). Writing a string INTO
  such a property (`obj.val = "*";`) had the identical gap in reverse.
- **Root cause:** `property_atom<T>` (the class handling `int`/`byte`/
  `shortint`/`longint` properties) and `property_logic` (4-state vector
  properties) never overrode `class_property_t::get_string`/
  `set_string`; every call fell to the base class's generic "unsupported"
  stub (warn once, return `""` / ignore the write). This was NOT a
  decimal/itoa-formatting gap as first hypothesized while triaging --
  confirmed against the LRM directly (6.16: "values of integral type can
  be assigned to a string variable... if the size of the integral value
  is not a multiple of 8 bits, [it] shall be zero-filled on the left") --
  it is a missing BYTE-PACKING conversion, identical in shape to the one
  a plain (non-property) vec4-typed variable's existing `%pushv/str` vvp
  opcode (`of_PUSHV_STR`, vthread.cc) already performs correctly.
- **Fix:** Extracted `of_PUSHV_STR`'s conversion (8-bit big-endian bytes,
  any all-zero byte dropped -- not just leading ones, per 6.16's "assigning
  the value 0 to a string character shall be ignored") into a shared
  `vector4_to_packed_string()` (`vvp/vvp_net.h`/`vvp_net.cc`), and
  refactored `of_PUSHV_STR` itself to call it (dedup, zero behavior
  change for the existing plain-variable path). Added `get_string`/
  `set_string` overrides to `property_atom<T>` and `property_logic`
  (`vvp/class_type.cc`) built on this shared helper for reads, and a new
  shared `pack_string_into_vec4_()` helper (right-justify, zero-fill or
  truncate on the left, mirroring `%cast/vec4/str`'s `of_CAST_VEC4_STR`
  semantics) for writes.
- **Scope:** `property_bit` (2-state `bit [N:0]` vectors) needed no
  change -- confirmed already correct before this fix (`obj.bit_prop`
  read as a string already worked), apparently materializing through the
  same path as `property_atom<T>` for common widths. `property_string`
  (actual `string`-typed properties) was already correct and untouched.
  X/Z bits in a `logic`-typed property contribute 0 to a packed byte,
  matching how the pre-existing plain-variable path already treats them
  (verified, no crash, no special-casing needed).
- **Permanent regression:**
  `ivtest/ivltests/sv_class_property_string_conversion.v` (new,
  `normal`) -- covers `int`/`byte`/`bit`/`logic` reads (including the
  zero-value-collapses-to-empty-string and X-bit cases) and `int`/
  `shortint` writes (including left-truncation for an over-length
  string).
- **Validation:** integrated ivtest 4991/4986/0F/2NI/3EF, JSON/VVP
  1873/0, UVM 357/0/0, NFA dual-run 58/58, UVM release matrix 15/15
  SMOKE_PASS, frontend all S1-S12.
- **Evidence:** `evidence/campaign-20260908/l42/`.


### L43 — Package imports after local declarations

- **State:** IMPLEMENTED; focused validation passes. Full regression
  qualification is deferred to the approximately ten-feature batch boundary
  under the user's 2026-09-14 validation cadence.
- **Origin:** DD-018, corrected after inspecting its invalid return-type reducer.
- **Expected:** legal imports in procedural declaration prefixes resolve local
  types and values without generating an executable operation. Imports after
  statements and direct conditional/loop imports remain rejected.
- **Root cause:** an existing import-as-statement production created `PNoop`,
  which fell into `Statement::elaborate`'s internal-error path.
- **Scope:** parser routing to declaration-capable lists, attribute handling,
  preserving explicit null statements for placement checks, focused tests.
- **Authority:** IEEE 1800-2017 and 1800-2023 A.2.1.3, A.2.6-A.2.8, 26.3.
- **Evidence:** `evidence/dd018-assessment/`; permanent
  `sv_procedural_package_import` tests. Both editions failed with six internal
  errors before the patch. See the current ACTIVE_WORK record for final gates.

### L44 — Compound stores to disjoint mixed-driver packed elements

- **State:** IMPLEMENTED; focused validation passes, batch regression pending.
- **Origin:** DD-019, unmodified OpenTitan PRINCE concat width assertion.
- **Fix:** compound partial stores use the existing unresolved-net partial-force
  route shared with ordinary assignments. No runtime assertion is relaxed.
- **Authority:** IEEE 1800-2017 and 1800-2023 6.5 and 11.4.1.
- **Validation:** original N=2/4/5/6 reducer passes in both editions; permanent
  tests verify two successive input values, preservation of continuously driven
  elements, ordinary dynamic index single evaluation and unknown-index no-write.
  Explicit wire procedural assignment remains rejected. Legacy 2/2, JSON 4/4.
- **Limit:** dynamic subparts of mixed-driver elements remain DD-021; full
  application qualification and batch-wide regression are not claimed.

### L45 — Reject unresolved bare task enables

- **State:** IMPLEMENTED; focused legacy 2/2, JSON 4/4 and real UVM smoke pass.
- **Origin:** DD-020: `missing_task()` compiled and execution continued after
  a warning. It now reaches the existing unknown-task elaboration error.
- **Authority:** IEEE 1800-2017/2023 13.3 and 23.8.1.
- **Scope:** bare unresolved calls after normal lookup. Qualified/class fallback
  gaps remain open. Forward, upward, compilation-unit and implicit class task
  calls must continue to work. Broad regression follows the batch cadence.

### L46 — Preserve packed-element bounds for indexed reads

- **State:** IMPLEMENTED; legacy 1/1, JSON 2/2, null/synthesis and negative
  checks pass both editions. DD-022 writes remain open.
- **Authority:** IEEE 1800-2017/2023 11.5.1.
- **Scope:** final indexed `+:`/`-:` reads after valid fixed packed prefixes
  retain a bounded carrier through nested select expressions. Out-of-range bits
  must read X without exposing neighboring packed elements. Shared runtime
  part-select conversion must preserve wide index magnitude and signedness;
  clipping must avoid overflow and retain in-range bits with X padding.
- **Limits:** writes, invalid earlier prefixes and dynamic-prefix elaboration
  remain open. DD-021 mixed-driver restrictions are unchanged.

### L47 — Wide part-select values through VPI arguments

- **State:** IMPLEMENTED; focused legacy 3/3, JSON 6/6, direct VPI checks
  in both editions, and null/synthesis checks pass.
- **Origin:** DD-023: formatting a wide out-of-range select returned aliased
  bits. The corresponding monitor case also crashed.
- **Fix:** preserve constant normalization and descriptor width; use the shared
  wide-index conversion for dynamic VPI bases. Out-of-range reads return X and
  writes have no effect; callbacks compare the actual selected value.
- **Scope:** value semantics and callbacks triggered by parent value changes.
  Full VPI metadata and index-only callback triggers are not qualified here.
- **Authority:** IEEE 1800-2017/2023 11.5.1 and VPI value/callback semantics.
  Range tags are handle relations; the existing integer range-query extension
  is not claimed as implementation of those standard relations.

### L64 — Function-valued constraint evaluation and argument ordering

- **State:** QUALIFIED for the evidenced subset; integrated locally in4bc02c51b /0c6d5994a.
- **Active ID:** CONSTRAINT-FUNCTION-PRESOLVE.
- **Root cause:** legal function-valued constraints were ignored or lacked typed
  per-object result transport and staged active-argument dependencies.
- **Authority:** IEEE 1800-2017 and 1800-2023 18.5.11, with array-method,
  constraint-guard, soft-constraint and null-handle rules for affected operands.
- **Scope:** pure legal input/const-ref calls, typed result capture, qualified
  and virtual dispatch, active scalar/member/element/size argument stages, one
  rollback transaction, static overlays, selected fixed-array operands, and
  conditional-member validity. No-argument body reads do not invent priority.
- **Validation:** 250 paired focused outcomes; 206 permanent cases in each
  harness; legacy5253 total/5248 pass/0 fail/2 NI/3 EF; JSON2189/0; real-DPI
  UVM357/0/0; NFA58/0; release15 smoke passes; frontend12 scenarios; make check.
  All seven gates used identical frozen artifacts and749 source/test/docs files.
- **Limits:** dynamic-foreach per-iteration function capture, broader inline
  wide-value transport, active returned-member aliases, selected indexed
  conditional handles and multi-prefix reductions remain gaps. This does not
  qualify all Clause18, IEEE1800.2, or whole unmodified OpenTitan/Caliptra DV.
- **Evidence:** session_logs/2026-09-14_constraint_function_presolve.md and
  its companion _qualification.json; failed earlier batches remain preserved.

### L65 — Multiple prefix indices on constrained fixed-array reductions

- **State:** IMPLEMENTED; focused tests pass; local batch qualified (see L65–L74 record).
- **Active ID:** CONSTRAINT-MULTIPREFIX-REDUCTION.
- **Authority:** IEEE1800-2017 7.12.3/18.5.8.2; IEEE1800-2023 7.12.3/18.5.7.2.
- **Reproducer:** evidence/constraint-multidim-reductions-l65/selected-row.sv
  is rejected in both editions on qualified localmain9ad50ce52.
- **Root cause:** reduction admission permits at most one selected prefix,
  and canonicalization only processes that first dimension.
- **Scope:** multiple constant prefix indices leaving one fixed integral
  unpacked dimension, all five reductions, normal with-expression semantics,
  exact active/state element identity, bounds and transactional rollback.
  Runtime-selected prefixes are a separate solver-expression capability.

L65 validation: root2/2, independent4/4 positive and2 paired negative cases, permanent8/8 each harness, neighbors6/6 each. Stable artifacts. All five reductions preserve exact selected row, width/sign, index(), modes and rollback. User cadence defers full suite to about ten features.

### L66 — Typed array return element storage

- **State:** IMPLEMENTED, focused validation; local batch qualified (see L65–L74 record).
- **Origin:** DD-031, scalar return paths intercepted real/string array elements.
- **Authority:** IEEE1800-2017/2023 13.4.1.
- **Scope:** real/string element reads/writes and real compound updates reuse emitted return-array storage, including automatic recursion, exact index evaluation and result copies.
- **Validation:** Focused checks pass; results and revision scope are owned by the evidence record below.
- **Evidence:** session_logs/2026-09-14_typed_array_return_elements.md.

### L67 — Packed-select expression increment/decrement

- **State:** IMPLEMENTED for the evidenced subset; local batch qualified (see L65–L74 record).
- **Origin:** DD-030 selected-width runtime aborts and context-width rejection.
- **Scope:** scalar packed-signal selections and scalar function-return storage; fixed-array receivers are addressed by L68; scalar property receivers are addressed by L69; fixed-array property receivers are addressed by L70; scalar nested packed carriers are addressed by L71; nested array/property carriers remain open.
- **Evidence:** [L67 session](session_logs/2026-09-14_packed_select_increment.md).
- **Standards disposition:** [Clause11 refinement](matrices/ieee1800_2017_clause_matrix.md#l67--packed-select-incrementdecrement-expressions-1136-1142).

### L68 — Packed-select expression updates within fixed-array words

- **State:** IMPLEMENTED for the focused subset; local batch qualified (see L65–L74 record).
- **Origin:** L67 retained a focused rejection for selected fixed-array words.
- **Scope:** fixed-array word and packed-index capture, bounds, result widths, automatic/return storage. Scalar class-property receivers are addressed by L69; fixed-array property receivers are addressed by L70; bounded inner-carrier work remains open.
- **Evidence:** [L68 session](session_logs/2026-09-14_array_packed_increment.md).

### L69 — Scalar class-property packed-select increment/decrement

- **State:** IMPLEMENTED for the focused subset; local batch qualified (see L65–L74 record).
- **Scope:** scalar integral property bit/part pre/post updates, captured receiver,
  bounds, contexts, inheritance/nesting, and readonly diagnostics.
- **Follow-up:** selected fixed unpacked-array properties are addressed by L70; dynamic container and inner-carrier work remains separate.
- **Evidence:** [L69 session](session_logs/2026-09-14_class_packed_increment.md).

### L70 — Fixed-array class-property word packed-select updates

- **State:** IMPLEMENTED for the focused subset; local batch qualified (see L65–L74 record).
- **Scope:** integral fixed-array property words, atomic selected update,
  multidimensional indices, bounds, contexts, and const diagnostics.
- **Evidence:** [L70 session](session_logs/2026-09-14_class_array_packed_increment.md).

### L72 — Constant-function string character evaluation

- **State:** IMPLEMENTED for the focused subset; local batch qualified (see L65–L74 record).
- **Origin:** DD026 re-assessed on L70; string arguments collapsed to one bit.
- **Scope:** preserve argument/local string values and evaluate typed character reads.
- **Evidence:** [L72 session](session_logs/2026-09-14_constant_string_character.md).

### L71 — Nested scalar packed increment/decrement

- **State:** IMPLEMENTED for the focused scalar packed-signal and function-return scope; local batch qualified (see L65–L74 record).
- **Remaining:** Nested array/property roots and the earlier-aborting intermediate-part-select probe require independent assessment.
- **Evidence:** [L71 session](session_logs/2026-09-14_nested_packed_increment.md).

### L73 — Constant-function string character writes

- **State:** IMPLEMENTED for focused local character writes and constant-function locality diagnostics; local batch qualified (see L65–L74 record).
- **Remaining:** Explicit package qualification in character lvalues is separate; runtime compound lowering is L74.
- **Evidence:** [L73 session](session_logs/2026-09-14_constant_string_character_write.md).

### L74 — Runtime scalar string character compound assignments

- **State:** IMPLEMENTED for focused scalar/local/ref character updates; local batch qualified (see L65–L74 record).
- **Remaining:** Whole-string compound operations, array receivers and function-return character storage are separate gaps.
- **Evidence:** [L74 session](session_logs/2026-09-14_runtime_string_character_compound.md).

### L65–L74 local qualification checkpoint

The [joint qualification record](session_logs/2026-09-14_compiler_batch_l65_l74_qualification.json) supersedes pending broad-test notes for the recorded candidate. The individual scope boundaries remain in force.

### L75 — String-function-return character stores

- **State:** IMPLEMENTED for scalar return characters; focused checks pass, broad batch pending.
- **Area / edition:** Runtime return storage; IEEE 1800-2017/2023 6.16, 11.4.1, 13.4.1.
- **Evidence:** `evidence/parallel-batch-l71-l72/l75-assessment/`: both editions leave ABC unchanged for plain/compound character writes to a function return. Plain selectors execute once; compound selectors are skipped.
- **Closure:** Plain and compound byte stores, signed arithmetic, index/RHS capture, bounds/defaults/zero-byte behavior and automatic/recursive return-slot isolation.
- **Last verified revision:** `e25971651` frozen candidate.

- **Focused implementation evidence:** [L75 session](session_logs/2026-09-14_string_return_character.md).

### L76 — Constant-function string case conversion

- **State:** LOCALLY QUALIFIED for the recorded toupper/tolower scope; see joint qualification below.
- **Area / edition:** Constant evaluator; IEEE 1800-2017/2023 6.16.4, 6.16.5, 13.4.3.
- **Evidence:** `evidence/next-constant-assessment/ASSESSMENT.md`: both editions reject the internal method during constant evaluation and then assert; runtime control passes.
- **Closure:** Correct byte conversion without receiver mutation, empty/high-byte/local/argument cases, runtime parity and focused invalid-call diagnostics.
- **Last verified revision:** `e25971651` frozen candidate.

- **Focused implementation evidence:** [L76 session](session_logs/2026-09-14_constant_string_case_conversion.md).

### L77 — Runtime string-character increment/decrement expressions

- **State:** LOCALLY QUALIFIED for the recorded subset; see joint qualification below.
- **Evidence:** `evidence/batch-20260914-after-l74/l77-baseline.json`: both editions abort loading string storage through the vector loader.
- **Scope:** Scalar string variables and scalar string returns, pre/post byte update/result semantics, bounds and index capture.
- **Standards:** IEEE 1800-2017/2023 6.16, 11.4.2.

- **Focused implementation evidence:** [L77 session](session_logs/2026-09-14_string_character_increment.md).

### L78 — Constant-function string comparisons

- **State:** LOCALLY QUALIFIED for the recorded subset; see joint qualification below.
- **Evidence:** `evidence/batch-20260914-after-l74/l78-baseline.json`: both editions reject constant compare/icompare evaluation.
- **Scope:** Case-sensitive and insensitive comparison signs, byte ordering, operand preservation and diagnostics.
- **Standards:** IEEE 1800-2017/2023 6.16.6, 6.16.7, 13.4.3.

- **Focused implementation evidence:** [L78 session](session_logs/2026-09-14_constant_string_comparison.md).

### L79 — Fixed-array string-character stores

- **State:** LOCALLY QUALIFIED for the recorded subset; see joint qualification below.
- **Evidence:** `evidence/batch-20260914-after-l74/l79-array-character-baseline.json`: both editions abort in target assignment lowering.
- **Scope:** Plain blocking byte writes to fixed unpacked-array string words; selector capture and bounds.
- **Standards:** IEEE 1800-2017/2023 6.16, 6.16.2, 7.4, 10.4.1.

- **Focused implementation evidence:** [L79 session](session_logs/2026-09-14_array_string_character_store.md).

### L80 — Constant-function substr

- **State:** LOCALLY QUALIFIED for the recorded subset; see joint qualification below.
- **Evidence:** `evidence/batch-20260914-after-l74/l80-constant-substr-baseline.json`: both editions reject method evaluation then assert.
- **Scope:** Inclusive substr evaluation with int indices, invalid-range empty results and receiver preservation.
- **Standards:** IEEE 1800-2017/2023 6.16.8, 13.4.3.

- **Focused implementation evidence:** [L80 session](session_logs/2026-09-14_constant_string_substr.md).

### L81 — Fixed-array string-character compound stores

- **State:** LOCALLY QUALIFIED for the recorded subset; see joint qualification below.
- **Evidence:** `evidence/batch-20260914-after-l74/l81-array-character-compound-baseline.json`: both editions skip the byte assignment and its side effects.
- **Scope:** Legal integral character compound operations on fixed string-array words; whole-string arithmetic is not legal scope.
- **Standards:** IEEE 1800-2017/2023 6.16, 11.4.1.

- **Focused implementation evidence:** [L81 session](session_logs/2026-09-14_array_string_character_compound.md).

### L82 — Constant string-to-integer conversion family

- **State:** LOCALLY QUALIFIED for the recorded subset; see joint qualification below.
- **Evidence:** `evidence/batch-20260914-after-l74/l82-constant-string-integer-baseline.json`: both editions reject all four conversion methods in constant functions.
- **Scope:** atoi/atohex/atooct/atobin with radix digits, underscore scanning, termination and 32-bit integer results.
- **Standards:** IEEE 1800-2017/2023 6.16.9, 13.4.3.

- **Focused implementation evidence:** [L82 session](session_logs/2026-09-14_constant_string_integer.md).

### L83 — Fixed-array string-character increment/decrement

- **State:** LOCALLY QUALIFIED for the recorded subset; see joint qualification below.
- **Evidence:** `evidence/batch-20260914-after-l74/l83-array-character-incdec-baseline.json`: both editions route string storage through the vector-array loader and fail runtime semantics.
- **Scope:** Pre/post signed character update/results on fixed string arrays, excluding array returns.
- **Standards:** IEEE 1800-2017/2023 6.16, 11.4.2.

- **Focused implementation evidence:** [L83 session](session_logs/2026-09-14_array_string_character_increment.md).

### L84 — Constant-function string-character increment/decrement

- **State:** LOCALLY QUALIFIED for the recorded subset; see joint qualification below.
- **Evidence:** `evidence/batch-20260914-after-l74/l84-constant-character-incdec-baseline.json`: both editions fail selected-character unary evaluation and assert downstream.
- **Scope:** Scalar local/argument/return string character pre/post byte updates and results in constant functions.
- **Standards:** IEEE 1800-2017/2023 6.16, 11.4.2, 13.4.3.

- **Focused implementation evidence:** [L84 session](session_logs/2026-09-14_constant_string_character_increment.md).

### L75–L84 local qualification checkpoint

The [joint qualification record](session_logs/2026-09-14_compiler_batch_l75_l84_qualification.json) supersedes pending broad-gate notes for these bounded subsets. Remote CI and complete application/edition support remain separate obligations.

### L85 — Ordered distributions in joint canonical scalar solves

- **Parent:** Z01.
- **State:** LOCALLY QUALIFIED for the recorded subset; see L85–L95 checkpoint below.
- **Evidence:** `evidence/next-batch-after-l84/baseline.json`; both editions reject a legal ordered weighted joint graph at runtime.
- **Scope:** Existing supported hard distribution family combined with bounded canonical scalar solve-before stages; correct stage marginals and conditional fibers.
- **Standards:** 2017 18.5.4/18.5.9/18.5.10; 2023 18.5.3/18.5.8/18.5.9.

- **Implementation evidence:** [L85 session](session_logs/2026-09-14_joint_ordered_distribution.md).

### L86 — Bounded delay-range antecedents in multiclock implications

- **Parent:** S01 residual scope.
- **State:** LOCALLY QUALIFIED for the recorded subset; see L85–L95 checkpoint below.
- **Evidence:** `evidence/next-batch-after-l84/baseline.json`; both editions reject the finite two-endpoint antecedent.
- **Scope:** Finite constant delay windows with all matching endpoints, correct clock handoff and preserved attempt/action semantics.
- **Standards:** IEEE 1800-2017/2023 16.6/16.7, 16.12.7, 16.13 and 16.14.1/.3.

L86 architecture refinement: scalar cross-clock request counts cannot retain the
parent of multiple antecedent matches. The coordinator authorized dynamic
parent-tagged transport and per-attempt verdict aggregation in ACTIVE_WORK.
The paired action-count reducer is preserved at
`evidence/next-batch-after-l84/parent-actions-baseline.json`; no candidate
qualification is established by this scope refinement.

L86 [implementation and validation](session_logs/2026-09-15_multiclock_bounded_antecedents.md) now provide the bounded delay-window foundation. S02 repetition remains separate.

### L87 — Joint selected integral array-element ordering

- **Parent:** Z01.
- **State:** LOCALLY QUALIFIED for the recorded subset; see L85–L95 checkpoint below.
- **Evidence:** `evidence/batch-20260914-after-l84/next-selection/baseline.json` at L85; both editions reject selected-element ordering.
- **Scope:** Statically selected fixed-array integral elements with exact ordered stage identity/projection; dynamic ordering and other unsupported families remain separate.
- **Standards:** 2017 18.5.9/18.5.10; 2023 18.5.8/18.5.9.

- **L87 implementation evidence:** [Focused session](session_logs/2026-09-14_joint_element_ordering.md).

### L88 — Joint dynamic-array selected-element ordering

- **Parent:** Z01.
- **State:** LOCALLY QUALIFIED for the recorded subset; see L85–L95 checkpoint below.
- **Evidence:** `evidence/batch-20260914-after-l84/next-dynamic-assessment/baseline.json`; both editions drop the ordering and produce685 first-element ones in1024 calls, violating the uniform first-stage oracle.
- **Scope:** Constant selected integral dynamic-array elements with one proved size before element solving; preserve resize, exact ordering, bounds and transaction invariants. Other container/order families remain separate.

- **L88 implementation evidence:** [Focused session](session_logs/2026-09-15_joint_dynamic_element_ordering.md).

### L89 — Joint queue selected-element ordering

- **Parent:** Z01.
- **State:** LOCALLY QUALIFIED for the recorded subset; see L85–L95 checkpoint below.
- **Evidence:** `evidence/batch-20260914-after-l84/next-queue-assessment/after-l88-baseline.json`; paired queue ordering is dropped and violates the first-stage probability oracle.
- **Scope:** Constant selected integral queue elements with one proved size, bounded queue limits, retained-element modes and exact joint ordering. Other queue/order families remain separate.

- **L89 evidence:** [Focused session](session_logs/2026-09-15_joint_queue_element_ordering.md).

### L90 — Packed selects on class-container enum elements

- **State:** LOCALLY QUALIFIED for the recorded subset; see L85–L95 checkpoint below.
- **Evidence:** `evidence/batch-20260914-after-l84/next-packed-assessment/typed-baseline.json`; paired enum element reads reject, while equivalent bit/signed/logic controls pass.
- **Scope:** Existing read and lvalue packed-select paths for class dynamic-array/queue enum elements, preserving nominal whole-enum typing and existing partial-write semantics.

- **L90 evidence:** [Focused session](session_logs/2026-09-15_enum_container_packed_selects.md).

### L91 — Finite Boolean consecutive repetition in multiclock antecedents

- **Parent:** S02.
- **State:** LOCALLY QUALIFIED for the recorded subset; see L85–L95 checkpoint below.
- **Evidence:** `evidence/batch-20260914-after-l84/next-repeat-assessment/baseline.json`; paired rejection of `a[*1:2]` despite the L86 delay-window foundation.
- **Scope:** Finite Boolean repetition with legal empty-match composition, endpoint/parent semantics, existing clock handoff and cancellation. Grouped and unbounded repetition remain distinct obligations.

- **L91 evidence:** [Focused session](session_logs/2026-09-15_multiclock_boolean_repetition.md).

### L92 — Fixed multiclock assertion control

- **Parent:** DD-032.
- **State:** LOCALLY QUALIFIED for the recorded subset; see L85–L95 checkpoint below.
- **Evidence:** `evidence/batch-20260914-after-l84/l92-baseline/baseline.json`.
- **Scope:** Gate fresh fixed multiclock attempts under Off/Kill while preserving pending completion, restart and selected-instance behavior; reuse existing control helpers.

- **L92 evidence:** [Focused session](session_logs/2026-09-15_fixed_multiclock_assertion_control.md).

### L93 — Constant-function string formatting silently leaves the receiver unchanged

- **State:** LOCALLY QUALIFIED for the recorded subset; see L85–L95 checkpoint below.
- **Evidence:** `evidence/batch-20260914-after-l84/next-string-format/baseline.json`; runtime paired control succeeds, constant paired invocation returns the empty string after clean compilation.
- **Scope:** Constant evaluation of the five string numeric-formatting methods; internal task lowering must retain the required function mutation. IEEE 1800-2017/2023 6.16.11–6.16.15 and 13.4.3.

- **L93 evidence:** [Focused session](session_logs/2026-09-15_constant_string_formatting.md).

### L94 — Finite grouped consecutive repetition in multiclock antecedents

- **Parent:** S02.
- **State:** LOCALLY QUALIFIED for the recorded subset; see L85–L95 checkpoint below.
- **Evidence:** `evidence/batch-20260914-after-l84/next-group-repeat/baseline.json`.
- **Scope:** Preserve and repeat the entire finite grouped Boolean/delay fragment, including legal empty alternatives and parent-level verdicts. Unbounded and general match-action groups remain separate.

- **L94 evidence:** [Focused session](session_logs/2026-09-15_multiclock_grouped_repetition.md).

### L95 — Constant-function putc silently skips mutation and arguments

- **State:** LOCALLY QUALIFIED for the recorded subset; see L85–L95 checkpoint below.
- **Evidence:** `evidence/batch-20260914-after-l84/next-putc-assessment/baseline.json`.
- **Scope:** Scalar local string and function-result character updates, IEEE1800-2017/2023 6.16.2 and13.4.3. Other receiver families remain separate.

- **L95 evidence:** [Focused session](session_logs/2026-09-15_constant_string_putc.md).

### L85–L95 local qualification checkpoint

The [batch record](session_logs/2026-09-15_compiler_batch_l85_l95_qualification.json) qualifies the eleven recorded subsets at `d45ee87ab`, including the [regression corrections](session_logs/2026-09-15_batch_l85_l95_regression_repair.md). Broader clause and application scope remains open.

### L96 — Constant-function non-input formals accepted

- **Area / edition:** Function elaboration / IEEE1800-2017 and2023 13.4.3.
- **State:** REGRESSION_TESTED; local seven-gate batch passed, publication CI pending.
- **Confidence:** REPRODUCED.
- **Evidence:** `evidence/batch-20260914-after-l84/next-const-formals-assessment/baseline.json`; both editions accept prohibited output/inout/ref constant calls.
- **Closure:** Reject prohibited formals in constant evaluation, including nested calls, while preserving input-only constant functions and ordinary runtime writable-formal calls. Paired diagnostics and behavioral controls required.
- **Last verified revision:** `e43ecd536` installed candidate, qualified at `d45ee87ab`.

- **Implementation evidence:** [L96 session](session_logs/2026-09-15_constant_function_formal_legality.md).

### L97 — Nested finite whole-sequence repetition rejected

- **Area / edition:** SVA / IEEE1800-2017 and2023 16.9.2,16.9.2.1,16.12.22,16.13.
- **State:** REGRESSION_TESTED; local seven-gate batch passed, publication CI pending.
- **Confidence:** REPRODUCED.
- **Evidence:** `evidence/batch-20260914-after-l84/next-nested-group-assessment/baseline.json`; both editions reject the nested exact-count endpoint witness.
- **Closure:** Preserve inner/outer copies and endpoints, nested empty composition and parent verdicts within the existing finite construction scope. Keep fixed pipeline and same-clock behavior correct; preserve loud unsupported boundaries.
- **Last verified revision:** `e43ecd536` installed candidate, qualified at `d45ee87ab`.

- **Implementation evidence:** [L97 session](session_logs/2026-09-15_nested_finite_grouped_repetition.md).

### L98 — Generated function accepted in constant evaluation

- **Area / edition:** Function elaboration / IEEE1800-2017 and2023 13.4.3.
- **State:** REGRESSION_TESTED; local seven-gate batch passed, publication CI pending.
- **Confidence:** REPRODUCED.
- **Evidence:** `evidence/batch-20260915-after-l95/next-constant-defaults-assessment/generate-baseline.json` at the L96/L97 focused install.
- **Closure:** Reject constant calls to functions declared in generate blocks, including nested/cached paths; preserve ordinary runtime generated functions and module/package constant functions. Paired edition tests required.
- **Implementation evidence:** [L98 session](session_logs/2026-09-15_generated_constant_function_legality.md).

### L99 — String methods lose fixed-array word mutations

- **Area / edition:** Constant evaluation and VPI array words / IEEE1800-2017 and2023 6.16,7.4,13.4.3.
- **State:** REGRESSION_TESTED; local seven-gate batch passed, publication CI pending.
- **Confidence:** REPRODUCED.
- **Evidence:** `evidence/batch-20260915-after-l95/next-string-array-method-assessment/baseline.json`; constant putc/itoa abort, runtime controls leave words unchanged in both editions.
- **Closure:** Correct selected fixed-array string mutation for all six mutating methods in constant and runtime paths, including locality, bounds, once-only evaluation and neighboring word preservation.

- **Implementation evidence:** [L99 session](session_logs/2026-09-15_fixed_string_array_methods.md).

### L100 — Finite multiclock consequence alternatives rejected

- **Area / edition:** SVA / IEEE1800-2017 and2023 16.9.2,16.12.7,16.12.22,16.13.2.
- **State:** REGRESSION_TESTED; local seven-gate batch passed, publication CI pending.
- **Confidence:** REPRODUCED.
- **Evidence:** `evidence/batch-20260915-after-l95/next-ranged-consequence-assessment/assessment.md`; internal one-copy consequence fails at50 while two-copy branch should succeed at90, but both editions reject the source.
- **Closure:** Distinct finite consequence NFA per child; one existential child result feeds universal parent aggregation. Preserve synchronization, controls, pending backlogs and unsupported construction boundaries with paired behavioral tests.

- **Implementation evidence:** [L100 session](session_logs/2026-09-15_finite_multiclock_consequences.md).

### L101 — Constant fixed-array string-character increment

- **State:** REGRESSION_TESTED; local seven-gate batch passed, publication CI pending.
- **Standards:** IEEE1800-2017 and2023 6.16,11.4.2,13.4.3.
- **Evidence:** `evidence/batch-20260915-after-l95/next-const-array-character-assessment/isolated-baseline.json`.
- **Closure:** Correct pre/post byte updates through the selected local fixed-array word, with runtime parity, once-only selectors, bounds and locality controls.

- **Implementation evidence:** [L101 session](session_logs/2026-09-15_constant_array_character_increment.md).

### L102 — Plain finite multiclock consequence alternatives

- **State:** REGRESSION_TESTED; local seven-gate batch passed, publication CI pending.
- **Standards:** IEEE1800-2017 and2023 16.9.2,16.13.1,16.13.2.
- **Evidence:** `evidence/batch-20260915-after-l95/next-plain-consequence-nfa-assessment/ASSESSMENT.md`.
- **Closure:** Fixed first-clock sequence prefix followed by finite second-clock alternatives yields a correctly timed single verdict per attempt, preserving clock boundaries, controls and pending backlogs.

- **Implementation evidence:** [L102 session](session_logs/2026-09-15_plain_multiclock_consequences.md).

### L103 — Plain multiclock ranged first-clock prefix

- **State:** REGRESSION_TESTED; local seven-gate batch passed, publication CI pending.
- **Standards:** IEEE1800-2017 and2023 16.9.2,16.13.1,16.13.2.
- **Evidence:** `evidence/batch-20260915-after-l95/next-plain-ranged-prefix-assessment/assessment.md`; both editions reject the legal finite ranged prefix.
- **Closure:** Existential complete-path aggregation for each plain sequence attempt, with exact times, all-fail/early-success behavior, controls, backlogs and preserved implication universality.

- **Implementation evidence:** [L103 session](session_logs/2026-09-15_plain_multiclock_ranged_prefix.md).

### L104 — Constant mixed integral/literal equality

- **State:** REGRESSION_TESTED; local seven-gate batch passed, publication CI pending.
- **Standards:** IEEE1800-2017 and2023 5.9, Table11-21,11.8.2.
- **Evidence:** `evidence/batch-20260915-after-l95/next-mixed-constant-equality-assessment/assessment.md`.
- **Closure:** Common integral operand sizing, signedness and four-state equality with constant/runtime parity.

- **Implementation evidence:** [L104 session](session_logs/2026-09-15_constant_mixed_equality.md).

### L105 — Fabricated nonlocal constant-function values

- **State:** REGRESSION_TESTED; local seven-gate batch passed, publication CI pending.
- **Standards:** IEEE1800-2017 and2023 13.4.3.
- **Evidence:** `evidence/batch-20260915-after-l95/next-static-constant-fallback-assessment/assessment.md`.
- **Closure:** Reject nonlocal mutable state during constant evaluation; retain actual runtime state and legal constant inputs.

- **Implementation evidence:** [L105 session](session_logs/2026-09-15_nonlocal_constant_function_values.md).

L96–L105 share the [local qualification checkpoint](session_logs/2026-09-15_compiler_batch_l96_l105_qualification.json).

### L118 — Queue/darray operand silently mistreated as vector bits in a concatenation select

- **Status:** CLOSED 2026-09-15. Found while investigating a `tasks/todo.md`
  Phase-B backlog item (`eval_string.c:249`'s silent select-on-unsupported-
  base-type fallback) — the reducer built to test it never reached that
  fallback at all, but surfaced this different, upstream bug instead.
- **Symptom:** `s = {qa, qb}[1];` where `qa`/`qb` are `string queue`s
  compiled with ZERO diagnostics and printed the wrong result (`s=""`,
  should be a real element) at runtime. Disassembly showed Icarus lowering
  `{qa, qb}` as a packed bit-vector concatenation (`%concat/vec4`) and then
  bit-selecting into it, rather than recognizing the queue operands.
- **Investigation correction (recorded so it isn't repeated):** initially
  read this as a MISSING FEATURE (IEEE 1800-2017/2023 10.10 unpacked-array
  concatenation, then an element select — primary grammar A.8.4 allows
  `concatenation [ [ range_expression ] ]`) and began implementing a
  `sorry:` diagnostic for it. Before finishing that, cross-checked with
  slang: `slang --std 1800-2017` REJECTS the identical construct outright
  (`error: invalid operand type 'string$[$]' in concatenation`), and the
  same for a non-string (`int`) queue. Re-reading 10.10: unpacked array
  concatenation requires an enclosing ARRAY-TYPED context (an assignment,
  argument, or pattern target) to be recognized as such; `{...}[...]` used
  as a bare sub-expression (the only way `PEPostSelect`'s base_ reaches a
  `PEConcat`) offers no such context, so a queue/darray operand there is
  simply illegal, not merely unimplemented. Reworded the diagnostic from
  `sorry:` (implies valid-but-unsupported) to `error:` (illegal) to match.
  This is the same discipline as [[discovered-debt-hypothesis-is-not-
  diagnosis]] (memory) — verify a hypothesis against a primary source
  before writing the fix, not just before closing the ticket.
- **Root cause:** `PEPostSelect::elaborate_expr` (elab_expr.cc) unconditionally
  elaborates its `base_` through `PEConcat`'s self-determined-width overload
  (a plain packed-vector concatenation), with no check on operand types —
  a queue/darray operand there was silently treated as vector bits instead
  of being rejected.
- **Fix:** added `postselect_concat_base_has_illegal_container_operand_()`
  (elab_expr.cc), checked right after `base_->test_width()` populates
  operand types: if any `PEConcat` operand covered by the select is itself
  queue/darray-typed (by `expr_type()`, or via `PEIdent::test_type_of_ident`
  for identifier operands), emit a focused `error:` citing IEEE
  1800-2017/2023 10.10 and reject, instead of silently mis-elaborating.
- **Scoped narrowly:** a concatenation of scalar queue/darray *elements*
  (e.g. `{q[0], q[1]}[3:0]`, the operands are scalars, not the container)
  is unaffected — verified with a permanent regression
  (`sv_concat_postfix_select_queue_element.v`) alongside the negative one.
  Plain packed-vector postfix-select (the pre-existing
  `sv_concat_postfix_select.v` coverage) is unaffected.
- **Permanent regression:** `ivtest/ivltests/sv_concat_postfix_select_queue_operand_fail.v`
  (CE, new `error:` diagnostic) and
  `ivtest/ivltests/sv_concat_postfix_select_queue_element.v` (normal,
  guards against a future false-positive on the scalar-element case), both
  registered in `ivtest/regress-sv.list` next to the existing postfix-
  select entries.
- **Validation:** focused 4/4 pass. Full `.github/ivtest_gate.sh` legacy
  sweep: `Total=5810, Passed=5805, Failed=0`, 0 unexplained vs. the
  `main`-tip (L96-L105) baseline. UVM regression: 357 passed, 0 failed, 0
  skipped. (json/nfa/releases/frontend/makecheck gates not re-run for this
  narrow, single-function fix — neither touched by the change.)
- **Not fixed here, deliberately:** actually IMPLEMENTING unpacked-array
  concatenation-then-element-select for the cases where it *is* legal
  (inside an array-typed context, e.g. `bigq = {qa, qb}; s = bigq[1];`,
  already two separate statements that already work today) is a real,
  separate feature, not touched by this fix. Nothing in this fix's scope
  claims that feature exists.

### L119 — `local::` outside an inline constraint block silently resolved as an ordinary property

- **Status:** CLOSED 2026-09-15. Found while probing `local::` (IEEE
  1800-2017/2023 18.7.1) for a hypothesized "snapshot the caller's value"
  defect. **The hypothesized defect did not exist** — `local::` works
  correctly for its real semantics (confirmed against the LRM's own
  worked example, §18.7.1: `function int F(C obj, integer x); F =
  obj.randomize() with { x < local::x; }; endfunction` — `local::x`
  binds to `F`'s own local argument, not a snapshot of `obj`'s property;
  reproduced exactly, 20/20 iterations correct). The investigation is
  recorded here anyway because it surfaced a real, different, narrower
  defect along the way.
- **Symptom:** `local::` used directly inside an ordinary CLASS-BODY
  `constraint` declaration (not an inline `randomize() with {...}`
  block) — e.g. `class c; rand integer x; constraint c1 { x <
  local::x; } endclass` — compiled with ZERO diagnostics and silently
  resolved `local::x` to the class's own (live, jointly-solved) property
  `x`, making the constraint an always-true tautology (`x < x` is never
  satisfiable, so in practice the constraint was effectively dropped/
  ignored by whatever fallback made the call still succeed).
- **LRM citation:** footnote 43 on the `constraint_block_item` production
  (A.2.11 in both editions): "The `local::` qualifier shall only appear
  within the scope of an inline constraint block." Confirmed independently:
  slang rejects the identical class-body construct with `'local'
  qualifier not allowed here`.
- **Root cause:** `pexpr_to_constraint_ir` (elaborate.cc) already had a
  correct, working handler for `local::` identifiers
  (`if (local_qualified && value_slots) return
  scope_randomize_value_slot_(...)`), gated on `value_slots` being
  non-null — `value_slots` is only ever non-null for an inline
  constraint's IR build (it's the argument-capture list an inline
  `with{}` clause needs; a plain class-body constraint has no
  randomize()-call-site scope to capture from, so it's built with
  `value_slots == nullptr`). When `local_qualified` was true but
  `value_slots` was null, there was no corresponding rejection — control
  fell through to the ordinary property-lookup path a few lines below,
  silently treating `local::x` as plain `x`.
- **Fix:** added the missing `if (local_qualified && !value_slots)` branch
  immediately after the existing (correct) inline-capture branch, emitting
  a focused `error:` citing 18.7.1 footnote 43 and returning `""` (which
  the existing dropped-constraint hard-error convention in this file
  already turns into a compile failure, not a silently weakened solve).
- **Scope:** the correct inline-`local::` path (already working, four
  pre-existing `ivtest` files cover it:
  `sv_constraint_function_argument_inline.v`,
  `sv_constraint_handle_inline.v`, `sv_struct_member_constraint_paths.v`,
  `sv_constraint_darray_size_local_scope.v`) is completely untouched —
  verified all four still pass.
- **Permanent regression:**
  `ivtest/ivltests/sv_constraint_local_outside_inline_fail.v` (CE, the
  class-body-`local::` rejection), registered in `ivtest/regress-sv.list`.
- **Validation:** focused 5/5 pass (new test plus the four existing
  inline-`local::` tests). Full `.github/ivtest_gate.sh` legacy sweep:
  `Total=5812, Passed=5807, Failed=0`, 0 unexplained. UVM regression: 357
  passed, 0 failed, 0 skipped.
- **Process note:** this is a repeat of the same discipline as L118 in
  this same session — an initial hypothesis (here: "`local::` doesn't
  snapshot correctly") was WRONG, caught by checking the LRM's own worked
  example and slang before writing any fix, which also reframed what the
  real, narrower, genuinely-broken case actually was. See
  [[discovered-debt-hypothesis-is-not-diagnosis]] (memory).

### L120 — Action-less `assert/assume property` on a liveness operator wrongly refused

- **Status:** CLOSED 2026-09-16. Found compiling real, unmodified
  Caliptra/Adams-Bridge formal-verification source
  (`submodules/adams-bridge/formal/fv_ntt_ctrl/fv_ntt_ctrl_constraints.sv`)
  directly — objective 5 grounding, not a synthetic reducer.
- **Symptom:** a completely action-less `assert property (s_eventually(x));`
  or `assume property (s_eventually(x));` — a bare `;` after the closing
  paren, no `else`, no statement of any kind — was rejected with `sorry:
  a pass action on this property operator is not supported (IEEE
  1800-2017 16.14.6)`, even though the source contains no pass action at
  all to refuse. Reproduced in complete isolation (a 7-line standalone
  reducer, no Caliptra dependency needed). Confirmed NOT specific to
  `assume`, or to any particular liveness shape: bare `assert`/`assume`
  on plain `s_eventually(x)` and on `1'b1 |-> s_eventually(x)` (a
  structurally different op_type reaching the same lowering) all hit it;
  `cover property (s_eventually(x));` was correctly unaffected (see root
  cause).
- **Root cause:** IEEE 1800-2017 A.2.10's "pass action only"
  `concurrent_assertion_statement` production
  (`assert_or_assume K_property '(' property_spec ')' statement_or_null`)
  represents a bare `;` trailing statement as a `PNoop` sentinel object,
  not a null pointer — the same sentinel shape `cover property (p);` and
  `... else ;` use. `pform_make_assertion()` (pform.cc) already consumed
  and cleared this sentinel for the fail-action case (any `kind`) and for
  `cover`'s pass-action case (`kind==2` only) — but never for
  assert/assume's pass-action case (`kind` 0/1). The uncleared `PNoop*`
  then reached `pform_make_temporal_assertion_()`'s
  `if (pass_stmt && !pass_supported)` check as a plain non-null pointer,
  indistinguishable from a genuine user-written pass action, for any
  property routed through that lowering (`op_type >= 4`: `within`,
  liveness, abort, and until-family operators) — which is exactly why
  none of this session's earlier, simpler SVA reducers (plain `|->`/`|=>`,
  `disable iff`+`$past`) had hit it: those operators don't reach this
  lowering at all.
- **Fix:** removed the `kind == 2 &&` restriction on the sentinel-clearing
  check in `pform_make_assertion()` (one line), making the "a null pass
  action has no executable behavior" consumption unconditional — matching
  what the pre-existing comment already said it should do. `cover
  property`'s own behavior is provably unchanged: it already hit this
  same clearing path before the fix (`kind==2` was already true for it),
  so removing the guard doesn't alter its control flow, only extends the
  same clearing to `kind` 0/1.
- **Scope verified narrow:** a REAL, non-empty pass action on a liveness
  operator (`assert property (s_eventually(x)) hits++;`) is still
  correctly refused with the identical diagnostic — confirmed directly,
  not assumed. `else`-only and combined pass+fail forms on liveness
  operators are unaffected (they never passed through the buggy
  sentinel path in the first place — only the pass-action-only grammar
  branch does). `cover property`'s already-correct behavior (own
  separate "not supported" message for unsupported operators) is
  unaffected, confirmed by direct comparison of its message before and
  after the fix.
- **Permanent regression:**
  `ivtest/ivltests/sv_assert_liveness_no_action.v` (normal — the fixed
  case, both `assert`/`assume` and both operator shapes) and
  `sv_assert_liveness_real_action_fail.v` (CE — confirms a genuine pass
  action is still refused), both registered in `ivtest/regress-sv.list`.
- **Validation:** focused 6/6 pass (both new tests plus four pre-existing
  liveness/assertion tests, confirming no regression to already-working
  shapes). Full `.github/ivtest_gate.sh` legacy sweep:
  `Total=5814, Passed=5809, Failed=0`, 0 unexplained. UVM regression:
  357 passed, 0 failed, 0 skipped.
- **Real-world confirmation:** the exact originally-failing real Caliptra
  file (`fv_ntt_ctrl_constraints.sv`, tested standalone with its package
  dependencies) now compiles with the two `sorry:` errors completely
  gone; remaining warnings on that file are pre-existing and unrelated
  (unresolved `bind`-target hierarchy references, from testing the file
  outside its full multi-file `bind` context — not a regression from
  this fix).

### L121 — Named property forward reference resolved as an undefined signal

- **Status:** CLOSED 2026-09-16. Found compiling real, unmodified
  Caliptra source directly (`src/sha512/formal/properties/
  fv_constraints.sv`), immediately after L120 — same session, same
  grounding approach.
- **Symptom:** `assert/assume property (name);` where `name` is a
  no-argument property declared LATER in the same module — legal per
  IEEE 1800-2017/2023 (no textual-order requirement between a
  `concurrent_assertion_statement` and the `property_declaration` it
  names; confirmed independently: slang accepts the identical construct,
  0 errors, 0 warnings) — was rejected with `error: Unable to bind
  wire/reg/memory 'name'`, exactly as if the name were genuinely
  undefined. Reproduced in a 15-line standalone isolated reducer. Two
  separate real, unmodified Caliptra files rely on this exact
  forward-reference shape (`src/sha512/formal/properties/
  fv_constraints.sv`, `src/sha512_masked/formal/properties/
  fv_constraints.sv`).
- **Root cause:** `sva_module_properties` (the map `pform_make_assertion`
  consults to resolve a bare `assert/assume/cover property (name);` to
  its declaration) is populated in single-pass textual parse order. A
  property declared after its first reference is not yet registered when
  that reference is reached, so resolution fell straight through to
  ordinary plain-identifier (signal) lookup and failed.
- **Fix:** mirrors the pre-existing, exactly-analogous deferred-clock-
  inference mechanism (`sva_pending_proc_` /
  `pform_sva_flush_pending_procedural`, called at end-of-module). Added a
  parallel `sva_pending_named_property_` list: when a bare single-
  identifier property reference is not found in `sva_module_properties`,
  park the full original call (loc/prop/fail_stmt/pass_stmt/kind/label)
  and retry once at end-of-module (`pform_sva_flush_pending_named_
  properties`, called before `pform_cur_module.pop_front()` so default-
  clocking lookup still resolves correctly on retry) by re-entering
  `pform_make_assertion` itself with the original arguments — by then
  every property declaration in the module has been parsed and
  registered. A name still unresolved at that point falls through to the
  original, unchanged plain-identifier error path — not a new message,
  no change for a genuinely undefined name (confirmed directly with a
  dedicated negative reducer).
- **Regression caught and fixed before landing (important process note):**
  the first version of this fix deferred on ANY unresolved single
  identifier, which also matches an ordinary already-declared signal used
  directly as a property body (`assert property (a);` where `a` is a
  plain `bit`/`wire` — indistinguishable from a forward-referenced
  property name at the point of first resolution). Deferring those too
  reordered their processing relative to other module items, which two
  VPI assertion-attempt-callback tests depend on for their attempt/
  instance numbering — caught immediately by the full ivtest gate's
  bundled VPI suite (`vpi/m12_assert_attempt.v`, `vpi/m12br_assert_cb2.v`
  went from 108/108 to 106/108, a real regression, not flakiness).
  Root-caused precisely (diffed the VPI gold output, found the `_0`/`_1`
  instance-index suffixes swapped) and fixed by narrowing the deferral
  condition with `pform_get_wire_in_scope()`: only defer when the name
  is not ALREADY resolvable as a known signal in scope, since such a
  name is never going to resolve as a property later instead. Re-ran the
  full VPI suite after the narrowing fix: back to 108/108.
- **Permanent regression:**
  `ivtest/ivltests/sv_assert_named_property_forward_ref.v` (normal — the
  fixed case, plus an ordinary-order property asserted alongside it to
  confirm the deferral machinery doesn't disturb already-working cases)
  and `sv_assert_named_property_undefined_fail.v` (CE — confirms a
  genuinely undefined name is still rejected identically), both
  registered in `ivtest/regress-sv.list`.
- **Validation:** focused 4/4 pass (both new tests plus L120's two).
  Full `.github/ivtest_gate.sh` legacy sweep: `Total=5816, Passed=5811,
  Failed=0`, 0 unexplained. Bundled VPI suite: 108/108 (the regression
  this fix's own first draft introduced, caught, root-caused, and fixed
  within the same investigation before ever being committed). UVM
  regression: 357 passed, 0 failed, 0 skipped.
- **Real-world confirmation:** the exact originally-failing
  `src/sha512/formal/properties/fv_constraints.sv` (with its real DUT,
  `sha512_core.v`) now compiles clean, exit 0.

### L122 — Comma-separated multi-identifier assertion-local variable declaration rejected as a syntax error

- **Status:** CLOSED 2026-09-16. Found compiling real, unmodified
  Caliptra source directly (`src/ecc/formal/properties/
  fv_ecc_pm_ctrl_abstract.sv`), while batch-scanning the `ecc` IP
  block's 24-file formal corpus — same real-corpus grounding approach as
  L120/L121.
- **Symptom:** `logic [5:0] addra, addrb;` — a comma-separated
  multi-identifier declaration inside a `property ... endproperty`
  block's local-variable section — was rejected with a plain `syntax
  error` pointing at the declaration line, followed by the expected
  cascade (`Unable to bind wire/reg/memory` for the property name). The
  single-identifier form (`logic [5:0] addra;`) already worked; only the
  comma continuation was rejected. Confirmed independently: slang
  (`--std 1800-2017`) accepts the identical construct, 0 errors, 0
  warnings — this is IEEE 1800-2017/2023 A.2.10's ordinary
  `assertion_variable_declaration ::= data_type
  list_of_variable_decl_assignments ';'`, ordinary comma-list variable
  declaration syntax used everywhere else in the language, not a
  special local-declaration-only restriction. Three genuine hits in the
  originally-scanned real file (all on `logic[5:0] addra,addrb;` lines,
  three separate properties), plus independently reproduced for the
  `int` form (`int a, b;`).
- **Root cause:** `parse.y`'s `sva_int_local_declarations` nonterminal
  had six alternatives (base and `sva_int_local_declarations`-chained
  forms, each for `K_int` and `K_sva_logic_local` with/without
  `dimensions`), and every one of them terminated in exactly one
  `IDENTIFIER ';'` — there was no comma continuation *within* a single
  declaration statement, only the (different, already-working) ability
  to chain multiple separate `;'-terminated declarations one after
  another (`logic [5:0] addra; logic [5:0] addrb;` always worked).
- **Fix:** added a new `sva_local_ident_list` nonterminal (returns
  `std::list<perm_string>*`), structurally identical to the pre-existing
  `sva_formal_list` comma-list pattern already used for parameterized-
  property formal argument lists — reused the same, already-proven-safe
  shape rather than inventing a new one. Replaced the bare `IDENTIFIER`
  in all six `sva_int_local_declarations` alternatives with
  `sva_local_ident_list`, and changed each action to loop over the
  returned list, calling `pform_sva_declare_int_local`/
  `pform_sva_declare_logic_local` once per name.
  `pform_sva_declare_logic_local(loc, name, dimensions)` previously
  always freed its `dimensions` argument (both the range-expression
  contents and the list container itself) unconditionally — calling it
  more than once with the same shared `dimensions` pointer (one call per
  comma-separated name) would double-free. Added an `owns_dimensions`
  parameter (default `true`, preserving every existing call site
  unchanged) so the grammar action passes `false` for every identifier
  in the list except the last, which alone releases the shared
  dimensions list once all clones have been made.
  `sva_local_dimension_width_()` was already safe to call once per
  identifier sharing the same `dimensions` list: it clones the range
  bounds (`sva_clone_expr_`) rather than consuming the originals, so
  each identifier still gets its own independent width expression tree
  — required since `pform_sva_end_local_declarations()` later deletes
  each map entry's `width` individually, and two entries sharing one
  `width` pointer would double-free there instead.
- **Verified in scope, not conflated with a separate pre-existing
  defect (important process note):** while building the permanent
  regression, mixing `int`-kind and `logic`-kind local declarations
  within one property (e.g. `int a; logic [3:0] z;`) was found to break
  binding of the `int`-typed name(s) at elaboration
  (`Unable to bind wire/reg/memory 'a'`) — but this reproduces with
  **zero commas involved**, using only the pre-existing single-
  identifier chain grammar this fix left untouched, so it is a separate,
  pre-existing defect, not a regression from this fix and not required
  for L122's closure. Recorded separately as DD-034 in
  `DISCOVERED_DEBT.md`; the L122 regression test deliberately declares
  only same-kind identifiers per property to stay in scope. See
  [[discovered-debt-hypothesis-is-not-diagnosis]] — verified the
  boundary of what this fix does and does not touch before claiming
  either construct implemented.
- **Bison grammar-safety check:** shift/reduce and reduce/reduce
  conflict totals compared before/after (`bison -y -d --report=state`):
  562/1122 identical in both, and the new rules are additive
  (`sva_local_ident_list` mirrors `sva_formal_list`'s already-safe
  shape) rather than modifying any existing production's alternatives.
- **Permanent regression:**
  `ivtest/ivltests/sv_assert_property_local_multi_ident_decl.v` (normal
  — functionally verifies both the `logic [N:0] a, b;` base form and an
  `int a, b; int c;` chain, matching values through the sequence rather
  than only checking compile success), registered in
  `ivtest/regress-sv.list`.
- **Validation:** focused 5/5 pass (this test plus L120's and L121's
  four). Full `.github/ivtest_gate.sh` sweep: `Total=5819, Passed=5814,
  Failed=0, Not Implemented=2, Expected Fail=3`, name-diff gate clean (0
  unexplained). Bundled VPI suite: 108/108. Negative suite: 148/148.
  UVM regression: 357 passed, 0 failed, 0 skipped.
- **Real-world confirmation:** the exact originally-failing
  `src/ecc/formal/properties/fv_ecc_pm_ctrl_abstract.sv` no longer
  produces the `syntax error` on any of its three `logic[5:0]
  addra,addrb;` declarations (grep-confirmed absent from the diagnostic
  output; one unrelated pre-existing `syntax error` at line 40, a
  standalone-file port-list type-resolution artifact from compiling
  this file outside its package context, is untouched by and out of
  scope for this fix).

### L123 — Parenthesized cycle-delay expression (`##(expr)`) rejected as a syntax error

- **Status:** CLOSED 2026-09-16. Found compiling real, unmodified
  Caliptra source directly (`src/ecc/formal/properties/
  fv_ecc_hmac_drbg_interface_constraints.sv`, line 67), continuing the
  same real-corpus scan of the `ecc` IP block's formal directory that
  found L122.
- **Symptom:** `##(time_window+1) hmac_drbg_valid;` — a parenthesized
  expression as a cycle-delay operand, where `time_window` is a
  property formal argument — was rejected with a plain `syntax error`.
  Reduced further: the rejection is unconditional on what the parens
  contain, including a pure compile-time-constant expression with no
  formal argument at all (`##(1+1)`) or even a single bare literal
  (`##(3)`) — every parenthesized form failed identically, while the
  unparenthesized bare-identifier form (`##tw`) already correctly
  reached a semantic diagnostic (`sorry: sequence cycle delays must be
  literal constants`) rather than a parse-time syntax error. Confirmed
  independently: slang (`--std 1800-2017`) accepts both `##(3+1)` and
  `##(tw+1)`, 0 errors, 0 warnings — this is IEEE 1800-2017/2023
  A.2.10's `cycle_delay_range ::= '##' constant_primary`, where
  `constant_primary` includes `'(' constant_mintypmax_expression ')'`.
- **Root cause:** `delay_value_simple` — the nonterminal shared by
  every `K_CYCLE_DELAY` (`##`) use site across SVA sequences/
  properties, procedural cycle delay, non-blocking cycle-delay
  assignment, ordinary `#` delay, and specify-path delay — has four
  alternatives (`DEC_NUMBER`, `REALTIME`, `IDENTIFIER`, `TIME_LITERAL`)
  and no parenthesized-expression alternative. The procedural
  cycle-delay statement production already worked around this locally
  by spelling `K_CYCLE_DELAY '(' expression ')' statement_or_null` as
  its own separate alternative (IEEE 1800-2017 14.11) rather than
  extending the shared nonterminal, but the six SVA sequence/property
  cycle-delay productions never got the same treatment.
- **Fix:** added a new `sva_cycle_delay_value` nonterminal
  (`delay_value_simple | '(' expression ')'`) and substituted it for
  `delay_value_simple` at exactly the six SVA-specific `K_CYCLE_DELAY`
  sites (`sva_multiclock_seq`, `sva_mc_tail`, the grouped-composite-
  sequence alternative of `property_expr`, `sva_seq_comb_concat`, and
  the leading/trailing-delay alternatives of `sva_seq_atom`).
  Deliberately scoped to only these six: `delay_value_simple` itself
  was left untouched to avoid any blast radius on the unrelated ordinary
  `#`-delay and specify-path contexts that also use it, and the two
  existing `K_CYCLE_DELAY` sites that don't need this fix (the
  procedural statement production, which already has its own explicit
  paren alternative; and the non-blocking cycle-delay assignment
  production, not evidenced as broken by any real source) were left
  alone.
  The downstream consumers (`pform_sva_single_delay`,
  `pform_sva_tree_concat`) already accepted an arbitrary `PExpr*` and
  fell back to a graceful diagnostic for a non-resolvable value —
  confirmed directly: `pform_sva_single_delay` already had a code
  comment anticipating exactly this shape ("A property formal can later
  substitute arithmetic here"), and the pre-existing bare-identifier
  `##tw` path already exercised that same fallback. No semantic-layer
  change was needed; this was purely a grammar gap.
- **Bison grammar-safety check:** shift/reduce and reduce/reduce
  conflict totals compared before/after (`bison -y -d --report=state`):
  562/1122 identical in both.
- **Permanent regression:**
  `ivtest/ivltests/sv_sva_cycle_delay_paren_expr.v` (normal — exercises
  the parenthesized-arithmetic form at the ordinary leading-delay
  position, plus a parenthesized-literal form through the separate
  multiclock-boundary production, confirming the new alternative is
  wired into more than one of the six touched call sites), registered
  in `ivtest/regress-sv.list`.
- **Validation:** focused pass (this test, compiles and runs correctly
  standalone). Full `.github/ivtest_gate.sh` sweep: `Total=5820,
  Passed=5815, Failed=0, Not Implemented=2, Expected Fail=3`, name-diff
  gate clean (0 unexplained). Bundled VPI suite: 108/108. Negative
  suite: 148/148. UVM regression: 357 passed, 0 failed, 0 skipped.
- **Real-world confirmation:** the exact originally-failing
  `src/ecc/formal/properties/fv_ecc_hmac_drbg_interface_constraints.sv`
  no longer produces the `syntax error` at line 67; the file now
  reaches only its remaining, already-documented `sorry:` limitations
  (parameter-valued consecutive repetition, a separate known gap) plus
  an expected standalone-compile artifact (`bind target module ... is
  not defined in this compilation`, from compiling this file outside
  its full project context).

### L124 — Unpacked-array range select unsupported as a module port-connection actual (closes DD-036)

- **Status:** CLOSED 2026-09-16. Found via a differential Icarus/slang
  static census over Caliptra's full integration filelists (patched
  copy of the pre-existing `run_census.py` census driver — see
  `[[census-driver-paths-rot]]` — pointed at this worktree's build),
  run to look for real defects beyond the `formal/` corpus already
  exhausted this session. Recorded first as DD-036 in
  `DISCOVERED_DEBT.md` with a precise root cause and a promising but
  unverified fix angle; the one open unknown noted there
  (word-vs-pin unit conversion) was resolved by reading
  `normalize_variable_unpacked()`'s and `decode_fixed_uarray_slice()`'s
  implementations directly, then the fix was implemented, built, and
  fully validated — this entry supersedes DD-036, which is now closed.
- **Symptom:** a range select on a single-dimension fixed unpacked
  array (e.g. `arr[hi:lo]`, selecting a contiguous element sub-range of
  the same element type) used as a module port-connection actual was
  rejected with `sorry: Array slices are not yet supported for
  continuous assignment.` Confirmed independently: slang
  (`--std 1800-2017`) accepts the identical construct, 0 errors, 0
  warnings. **This single gap was the only thing blocking Icarus from
  compiling Caliptra's full-chip `caliptra_top` integration target at
  all** — the census's `ICARUS_GAP` category had exactly 5 entries
  (`ntt_masked_mult_reduction_tb`, `ntt_top`, `abr_top`,
  `caliptra_top`, `caliptra_top_ss_mode`), and diffing each target's
  full error set showed all five traced to the exact same two real,
  unmodified source sites
  (`submodules/adams-bridge/src/ntt_top/rtl/ntt_masked_special_adder.sv:102-103`,
  `submodules/adams-bridge/src/abr_libs/rtl/abr_masked_add_sub_mod_Boolean.sv:134-135`
  — both connect a `WIDTH`-element slice out of a `WIDTH+1`-element
  unpacked array straight to a submodule port, e.g.
  `.r0(r0_c0_delayed[WIDTH-1:0])`).
- **Root cause:** `PEIdent::elaborate_unpacked_net()`
  (`elab_net.cc:1607`) already implements a "slice view" mechanism —
  build a `NetNet::IMPLICIT` view net and `connect()`-alias it onto a
  contiguous pin range of the source net — but only for a *sibling*
  index shape: a partial index that supplies fewer indices than the
  source array has dimensions (reducing dimensionality, e.g. `arr2d[i]`
  on a 2-D array yielding a 1-D sub-array). A same-dimension-count
  range select (`SEL_PART`/`SEL_IDX_UP`/`SEL_IDX_DO` in
  `index_component_t`, rather than a plain `SEL_BIT` index) is a
  different shape that `indices_to_expressions()` explicitly rejects
  ("Array cannot be indexed by a range") if fed to it, so the code
  never even attempted the slice-view path for this shape — it fell
  straight through to the `sorry:`.
- **Fix:** rather than reimplementing bound/direction decoding,
  reused `decode_fixed_uarray_slice()` (`netmisc.h`/`netmisc.cc`), a
  general fixed-unpacked-array-slice decoder already relied on by
  three *other* contexts (function/task argument binding, concatenation
  operands, an lvalue path) but never wired into module port
  connections. Added a second branch in
  `PEIdent::elaborate_unpacked_net()`, engaged only when the source has
  exactly one unpacked dimension and the target formal is itself a
  fixed unpacked array: call `decode_fixed_uarray_slice(des, scope,
  *this, this, false, slice)`; on success, build the exact same
  `NetNet::IMPLICIT` + `connect()` view-net pattern the existing
  partial-index branch already uses, but pin-aliased starting at
  `slice.canonical_base` instead of the partial-index branch's
  `normalize_variable_unpacked()`-derived base. Confirmed by reading
  both functions directly (not assumed) that `canonical_base` and the
  existing branch's `base` are in the same word/pin-index space for a
  1-D unpacked array (`normalize_variable_unpacked()`'s stride-based
  canonical address and `decode_fixed_uarray_slice_select_()`'s
  `low - declared_low` compute identically for a single dimension), so
  no unit conversion was needed. On decode failure (`rc < 0`,
  recognized-but-invalid shape, e.g. a direction mismatch),
  `decode_fixed_uarray_slice()` has already reported its own precise
  diagnostic, so the new branch returns immediately without also
  emitting the generic `sorry:` (avoiding a confusing double message).
  On `rc == 0` (not this shape at all) or a shape/type mismatch against
  the target formal, control falls through unchanged to the existing
  `sorry:` — every other case this function already handled is
  untouched.
- **Verified for simulation correctness, not just compile success:**
  a functional reducer (see permanent regression below) confirms the
  view net is wired to the *correct* pins — element-by-element value
  matching, the out-of-range element (outside the slice) correctly
  excluded and its later changes not leaking into the slice, and a
  post-elaboration change to an in-range element correctly propagating
  live through the connection (it is a real net alias, not a one-shot
  copy). Also confirmed the ascending-declared-array direction (not
  just descending) and the negative direction-mismatch case (properly
  rejected with `decode_fixed_uarray_slice()`'s own diagnostic,
  unchanged).
- **Permanent regression:**
  `ivtest/ivltests/sv_unpacked_array_slice_port_conn.v` (normal —
  functional value/exclusion/live-propagation checks, not just compile
  success) and `sv_unpacked_array_slice_port_conn_dir_fail.v` (CE — the
  direction-mismatch negative case), both registered in
  `ivtest/regress-sv.list`.
- **Validation:** focused 2/2 pass. Full `.github/ivtest_gate.sh`
  sweep: `Total=5822, Passed=5817, Failed=0, Not Implemented=2,
  Expected Fail=3`, name-diff gate clean (0 unexplained). Bundled VPI
  suite: 108/108. Negative suite: 148/148. UVM regression: 357 passed,
  0 failed, 0 skipped.
- **Real-world confirmation:** re-ran the exact census commands for all
  5 previously-`ICARUS_GAP` targets directly — `ntt_top` and
  `caliptra_top` both now compile with `-tnull` at exit 0, zero
  diagnostic lines. Re-ran the full 106-target census:
  `ICARUS_GAP: 0` (was 5), all five previously-failing targets now
  report zero Icarus errors/warnings
  (`evidence/caliptra-census-20260916/caliptra-static-census.json`).
  **This closes the single defect that was blocking Icarus from
  compiling Caliptra's full-chip `caliptra_top` target at all** —
  directly serving mission objective 5.

### L125 — Confirmed regression: object method call on a class member misresolved as a bare parameterized-class reference

- **Status:** CLOSED 2026-09-16. Found via a full-corpus differential
  OpenTitan census (`scripts/opentitan_matrix.py`, 530 jobs, unmodified
  `opentitan-upstream` @ `7a3ad34b6`), run after the Caliptra `formal/`
  corpus and the Caliptra full-integration census were both already
  exhausted this session. **This is the first genuine regression found
  this session** (L118-L124 were all pre-existing gaps in previously-
  untested real corpus, not regressions) — root-caused with a proper
  same-script, per-job diff against a freshly rebuilt pre-session
  baseline before any fix was attempted, per
  `[[verify-against-freshly-built-main-baseline]]`.
- **Symptom:** `receiver.method()`, where `receiver` is an ordinary
  class-member (or local) variable whose *declared type's name* happens
  to coincide with an unrelated class's name declared elsewhere in the
  design, was rejected with `error: Parameterized class 'name' requires
  an explicit #(...) specialization before ::.` — even though the
  actual source uses ordinary `.` member/method access, never `::`, and
  `receiver` unambiguously names a variable, not a type. Reduced to a
  20-line standalone case; confirmed independently: slang
  (`--std 1800-2017`) accepts the identical construct, 0 errors, 0
  warnings.
  Real, unmodified OpenTitan DV source hits this directly:
  `hw/dv/sv/dv_base_reg/dv_base_reg_field.sv` declares `dv_base_mubi_cov
  mubi_cov;` (a member variable) and calls `mubi_cov.create_cov(width)`;
  `dv_base_mubi_cov.sv` (a sibling file in the same package) separately
  declares an unrelated `class mubi_cov #(parameter int Width = 4, ...)`
  — the name collision is between the *variable* and the *unrelated
  class*, not a self-reference. `dv_base_reg_field.sv` is common DV
  infrastructure; this broke compilation of `lowrisc:dv:tl_agent_sim`
  and all eight `top_*_xbar_{main,peri}_sim` cores across all three
  OpenTitan tops (earlgrey, darjeeling, englishbreakfast).
- **Confirmed as a real regression, not a pre-existing gap newly
  surfaced:** built the compiler at `631bba6e8` (PR #277, the last
  reliably-documented clean baseline: "OpenTitan census ... PASS 203 |
  FAIL 84 | ... RUNTIME_FAIL 23" exactly reproduced with today's
  `scripts/opentitan_matrix.py`, confirming that script version is the
  right comparison point) and ran the 20-line reducer directly: exit 0,
  clean. The same reducer on current `main` (before this fix): rejected.
  Bisected by building at each intervening squash-merge PR
  (`d9bfbaeee`, `8346955a6`, `5c0f5588e`, `9c8f716b1`, `874e00680`,
  `c45760199`, `34cd45c6b`, `5e0df21fd`) and re-testing the reducer at
  each: first broken at `5c0f5588e` (PR #280, "L43-L64"), the squash
  commit immediately after the clean `631bba6e8` baseline.
- **Root cause:** `PCallTask::elaborate_usr()`'s dotted-call resolution
  (`elaborate.cc`) added new machinery in PR #280 to support calling an
  inherited static class method via a bare class-scoped name with
  implicit `this` (`resolve_scoped_class_method_task_`, extended with
  `deferred_type_parameter`/`illegal_nonstatic`/`use_implicit_this`
  outputs). For a two-component dotted call (`receiver.method()`), this
  new resolution path is tried and its "receiver is a bare, unspecialized
  parameterized class name" diagnostic is acted on *before* checking
  whether `receiver` already resolves as an ordinary variable in scope
  — so a variable whose type happens to share a name with any
  parameterized class anywhere in the design gets misidentified as a
  reference to that unrelated class. The sibling call site for the
  *expression-call* context (`PCallTask::elaborate_method_`, further
  down in the same file) already had the correct guard
  (`if (net == 0) { ... resolve_scoped_class_method_task_(...) ... }`
  — only attempted when ordinary symbol resolution already failed to
  find a net); only the statement-call site (`elaborate_usr`) was
  missing it.
- **Fix:** added the same "does the receiver already resolve as an
  ordinary variable?" guard to the statement-call site: before invoking
  `resolve_scoped_class_method_task_` for a two-component call, resolve
  the single-component receiver via `symbol_search()`; if it finds an
  ordinary net (`sr.net != nullptr`), skip the scoped-class-name
  resolution entirely (`static_method` stays null) and fall through to
  the existing, unchanged ordinary object-method dispatch
  (`elaborate_method_`) below. Confirmed the already-correct sibling
  call site needed no change.
- **Verified the fix doesn't disturb what PR #280 added:** direct
  reducers confirm (1) an inherited static task called via a bare name
  with implicit `this` still resolves and runs correctly, (2) a
  genuinely bare, unspecialized parameterized class reference (`gc::
  hello();` with no shadowing variable) still correctly errors
  unchanged, and (3) an explicit specialized scoped-static call
  (`gc#(8)::hello();`) still works correctly.
- **Permanent regression:**
  `ivtest/ivltests/sv_class_member_shadows_unrelated_class_name.v`
  (normal — reproduces the exact real-world shape: an unrelated
  parameterized class sharing a name with a plain class-member
  variable, and a functional check that the method call actually ran,
  not just that it compiled), registered in `ivtest/regress-sv.list`.
- **Validation:** focused pass (this test, plus the three PR #280
  behavior-preservation reducers above). Full `.github/ivtest_gate.sh`
  sweep: `Total=5821, Passed=5816, Failed=0, Not Implemented=2, Expected
  Fail=3`, name-diff gate clean (0 unexplained). Bundled VPI suite:
  108/108. Negative suite: 148/148. UVM regression: 357 passed, 0
  failed, 0 skipped.
- **Real-world confirmation:** re-ran the full 530-job OpenTitan census
  with the fixed compiler. `lowrisc:dv:tl_agent_sim:0.1` (`uvm` lane):
  `FAIL -> PASS`. The `mubi_cov` error is confirmed completely gone from
  every previously-affected `top_*_xbar_*_sim` core's `hard_errors` list
  (checked directly, not inferred) — those cores do not flip all the way
  to `PASS` because the compile now progresses further and reaches a
  separate, deeper, pre-existing issue in `tlul_assert.sv` (`bind`-scope
  signal binding inside a generated instance path, `tb.dut.
  tlul_assert_host_rv_core_ibex__corei`), unrelated to this fix and out
  of its scope — exactly the documented "a frontier fix usually ADVANCES
  a core's first diagnostic rather than clearing it" pattern. Not
  claimed as closing those cores; only the `mubi_cov` misresolution
  itself is closed.

### L126 — Regression: named sequence solo-referenced inside a generate block loses its scope on deferred retry (fixes the L125-uncovered `tlul_assert` frontier)

- **Status:** CLOSED 2026-09-16. Found by chasing the exact deeper
  frontier L125 uncovered (see L125's "real-world confirmation" —
  `top_*_xbar_*_sim` advanced past `mubi_cov` to a `tlul_assert.sv`
  "Unable to bind wire/reg/memory" error on a sequence name). **This is
  a regression in this session's own L121 fix** (named-property
  forward-reference deferral, merged in PR #289) — the second
  self-introduced regression found and fixed this session, again via
  same-script/same-corpus verification before and after, not assumed.
- **Symptom:** a named sequence declared inside a conditional generate
  block, referenced as the *entire* property expression of an
  assert/cover statement in the *same* block (no forward reference —
  the declaration is textually first), was rejected with `error:
  Unable to bind wire/reg/memory 'name'` — as if the sequence name were
  undefined, even though it is declared right above its use. Reduced to
  a 10-line case; a named-sequence reference *inside a longer chain*
  (`x ##1 seq_name ##1 y`) in the same generate block already worked
  correctly — only the *solo* reference (the sequence IS the whole
  property expression) was affected. Confirmed independently: slang
  (`--std 1800-2017`) accepts the identical construct, 0 errors.
  Real, unmodified OpenTitan RTL (`hw/ip/tlul/rtl/tlul_assert.sv`)
  relies on exactly this shape: the `TLUL_D_CHAN_CONTENT_CHANGED_WO_
  ACCEPTED`/`TLUL_COVER` macros declare a `sequence ..._S; ...
  endsequence` inside `if (EndpointType == "Host") begin :
  gen_host_cov`, referenced solo by a `cover property (...)` in the
  same block — used by essentially every TL-UL-connected DV testbench.
- **Root cause:** L121's deferral guard (`pform.cc`,
  `pform_make_assertion`'s "named property instantiation" handling)
  parks an unresolved bare single-identifier reference as a possible
  forward-referenced *property*, retried at end-of-module — guarded to
  skip deferral when the name is already resolvable as a known signal
  (added when L121's first draft broke VPI attempt-callback ordering,
  see L121's entry above). It did **not** also skip deferral when the
  name was already resolvable as a known *sequence*
  (`sva_module_sequences`) — and a solo sequence reference is never
  going to appear in the *properties* map at all, so it unconditionally
  looked exactly like an unresolved-property shape and always got
  deferred. The deferred retry re-enters `pform_make_assertion` at
  end-of-module, using `pform_cur_generate` (whatever generate block is
  lexically active *at retry time*) to resolve the name — but by
  end-of-module every generate block has already closed, so
  `pform_cur_generate` no longer matches the `PGenerate*` the sequence
  was actually declared under (`sva_scoped_name_t`'s key includes the
  declaring generate block). This "worked" by pure accident at plain
  module scope (both a module-scope declaration's key and the deferred
  retry's implicit scope are `nullptr`) and failed only inside any
  generate block — which is exactly why this was not caught by L121's
  own validation (its reducers were all module-scope) and only surfaced
  now via real corpus with generate-scoped sequences.
- **Fix:** added a third deferral guard alongside the existing
  not-already-a-signal check: also skip deferral when the name is
  already resolvable as a known sequence in the *current* (still
  correct) scope, via `sva_in_scope_(sva_module_sequences, name)`. Such
  a reference falls straight through to the existing, unchanged ordinary
  sequence-splicing path (`sva_splice_sequences_`, already scope-correct
  since it runs immediately, not deferred) instead of being parked.
- **Verified independently as a regression, not a pre-existing gap:**
  built the compiler at `34cd45c6b` (L118, immediately before L119-
  L123/L121 landed) and confirmed the reducer compiles clean there
  (exit 0); the identical reducer on `main` before this fix (with L121
  but not this fix) fails. Also confirmed the failing regression test
  added for this fix genuinely fails when only L125's `elaborate.cc`
  change is cherry-picked without this `pform.cc` change (isolating the
  two fixes from each other).
- **Permanent regression:**
  `ivtest/ivltests/sv_sequence_solo_ref_in_generate_block.v` (normal —
  exercises both the exact real-world shape, a `cover property` solo
  reference, and a functional `assert property` implication using the
  same solo reference, checked against a driven waveform, not just
  compile success), registered in `ivtest/regress-sv.list`.
- **Validation:** focused pass (this test, plus the chain-in-generate-
  block reducer confirming no regression to the already-working case).
  Full `.github/ivtest_gate.sh` sweep: `Total=5822, Passed=5817,
  Failed=0, Not Implemented=2, Expected Fail=3`, name-diff gate clean (0
  unexplained). Bundled VPI suite: 108/108 (re-confirms L121's own
  attempt-callback-ordering regression stays fixed — this change adds a
  guard to the same function). Negative suite: 148/148. UVM regression:
  357 passed, 0 failed, 0 skipped.
- **Real-world confirmation:** re-ran the full 530-job OpenTitan census
  with the fixed compiler (on top of L125). `uvm`-lane result: **all
  eight `top_*_xbar_{main,peri,mbx,dbg}_sim` cores across all three
  OpenTitan tops (earlgrey, darjeeling, englishbreakfast) flip `FAIL ->
  PASS`** — the full crossbar DV family now compiles clean. A further
  ~13 `uvm`-lane cores (`adc_ctrl_sim`, `dma_sim`, `hmac_sim`,
  `mbx_sim`, `pattgen_sim`, `rv_timer_sim`, `soc_dbg_ctrl_sim`,
  `uart_sim`, `gpio_sim` across multiple tops, `rstmgr_sim`) advance
  from a genuine Icarus compile `FAIL` to `DEBT`/`UPSTREAM_INVALID`
  (i.e. Icarus itself no longer errors on them; whatever those
  categories track is a separate, non-Icarus concern). `uvm`-lane PASS:
  190 → 198.

### L127 — Crash: elaboration-time `$fatal()`/`$error()`/`$warning()`/`$info()` segfaults on an unelaboratable argument

- **Status:** CLOSED 2026-09-16. Found in the same OpenTitan `sva`-lane
  census scan that led to L125/L126 — `lowrisc:{earlgrey,darjeeling}_dv:
  otp_ctrl_sva:0.1` both showed a raw process crash (`Segmentation
  fault: 11`, `hard_errors` truncated mid-message) rather than any
  ordinary diagnostic. **A crash is categorically worse than a
  diagnostic gap** — it produces no error message at all, violating the
  project's bar that unsupported/invalid input must produce a focused
  diagnostic, not silently (or violently) fail.
- **Symptom:** an elaboration-time system-task call
  (`$fatal`/`$error`/`$warning`/`$info`, IEEE 1800-2017/2023 clause
  20.11) whose argument fails to elaborate as an expression (e.g. a
  bare identifier that is not declared anywhere) crashed the compiler
  with SIGSEGV instead of reporting a clean error. Real, unmodified
  OpenTitan RTL (`hw/{top_earlgrey,top_darjeeling}/ip_autogen/otp_ctrl/
  rtl/otp_ctrl.sv`) hits this directly via `hw/ip/prim/rtl/
  prim_assert_standard_macros.svh`'s `` `ASSERT_INIT `` macro: under
  `` `ifdef FPV_ON ``, it expands to `if (!(__prop)) $fatal(2, "...%s...
  %s...", (__name), (__prop));` where `__name` is the assertion's own
  bare label token (e.g. `ScrmblKeyNotAllZero_A2`) substituted
  unquoted — an undefined identifier in this expression context, not a
  string literal. Confirmed independently: slang (`--std 1800-2017`)
  also rejects the reduced construct ("use of undeclared identifier"),
  confirming a clean compile error is the correct response here, not a
  crash — this is arguably an upstream macro issue for the `FPV_ON`
  path, but that changes nothing about Icarus's obligation to fail
  safely rather than crash on it.
- **Root cause:** `PCallTask::elaborate_elab()` (`elaborate.cc`,
  ~line 17789) calls `elab_sys_task_arg()` for each argument and, if the returned
  `NetExpr*` fails `check_parm_is_const()`, prints a diagnostic
  including the argument's current value (`*eparms[idx]`) — but never
  checked whether `elab_sys_task_arg()` had returned `nullptr` (which
  it does when an argument fails to elaborate at all, e.g. an
  undefined identifier — already reported as a `warning: Unable to
  bind wire/reg/memory` compile-progress message by that point).
  `check_parm_is_const(nullptr)` itself is safe (a `dynamic_cast` on a
  null pointer is well-defined and just returns false), but the
  subsequent `cerr << ... << *eparms[idx] << ...` dereferences the null
  pointer directly, crashing mid-print — explaining the exact
  truncated error text captured in the census (`"Elaboration task
  $fatal() parameter [3] '"` then nothing, then the shell's own
  SIGSEGV report merged into the same output stream).
- **Fix:** added an explicit null check on `eparms[idx]` before the
  `check_parm_is_const()`/print step: when `elab_sys_task_arg()`
  returns `nullptr`, count it as a non-constant parameter (advancing
  `des->errors` and clearing `const_parms`, exactly as the existing
  non-constant case does) without dereferencing anything, relying on
  the earlier compile-progress warning already emitted by
  `elab_sys_task_arg()` itself to explain why. No other behavior
  changed — a fully-elaborable-but-non-constant argument still gets
  the original, unchanged "is not constant" message with its value
  printed.
- **Verified the existing working cases are unaffected:** a single
  fully-elaborable string-literal `$fatal` argument still prints its
  message and fails elaboration exactly as before; a multi-argument
  `$fatal` where every argument elaborates fine (just more than the
  currently-supported single string) still hits the existing,
  unrelated `sorry: Elaboration tasks currently only support a single
  string argument` limitation, unchanged; a generate-`if` branch where
  the `$fatal` guard condition is false (so the argument is never even
  evaluated) still compiles clean, unchanged.
- **Permanent regression:**
  `ivtest/ivltests/sv_elab_task_fatal_undef_arg_fail.v` (CE — the exact
  crash-triggering shape, confirmed the harness's captured stderr
  matches on the first attempt, no crash), registered in
  `ivtest/regress-sv.list`.
- **Validation:** focused 1/1 pass. Full `.github/ivtest_gate.sh`
  sweep: `Total=5823, Passed=5818, Failed=0, Not Implemented=2, Expected
  Fail=3`, name-diff gate clean (0 unexplained). Bundled VPI suite:
  108/108. Negative suite: 148/148. UVM regression: 357 passed, 0
  failed, 0 skipped.
- **Real-world confirmation:** the exact originally-crashing
  `lowrisc:{earlgrey,darjeeling}_dv:otp_ctrl_sva:0.1` `sva`-lane targets
  no longer crash — both now exit with a normal nonzero status and a
  clean list of 11 `warning: Unable to bind wire/reg/memory` compile-
  progress diagnostics (one per affected `` `ASSERT_INIT `` use), not a
  signal-based abnormal termination. Not claimed as closing those two
  targets to `PASS` — the underlying macro issue (an undefined
  identifier used as a format argument under `FPV_ON`) is a separate,
  likely-upstream concern outside this fix's scope; only the crash
  itself is closed.

### L128 — Crash: `static`/`automatic` qualifier before `task`/`function` at module scope entered unrecoverable parser panic-mode, eventually corrupting generate-scheme state and aborting (closes DD-038)

- **Status:** CLOSED 2026-09-16. Closes **DD-038**
  (`lowrisc:dv:spid_upload_sim:0.1`, SIGABRT via an `ivl_assert`/
  `assert()` failure in `pform_endgenerate`). Root-caused precisely
  after DD-038's own follow-up investigations (same session) had
  already identified the first syntax error's construct and the
  grammar-level reason it produces a raw `syntax error` at all; this
  entry implements and validates the fix.
- **Symptom:** `static task host();` (a `static`/`automatic` qualifier
  used as a *prefix* before `task`/`function`, the class-method-only
  form) declared directly in a module body — not inside a class —
  produced a raw, unhandled bison `syntax error` at the qualifier
  token itself. On real files with several such declarations followed
  by substantial unrelated content (e.g. a large procedural
  `case (cmd) inside ... endcase` block), the resulting panic-mode
  error recovery corrupted parser-internal generate-scheme bookkeeping
  badly enough that a later, syntactically-unrelated construct crashed
  the compiler outright (`Assertion failed:
  (pform_cur_generate->scheme_type == PGenerate::GS_CASE_ITEM ||
  parent_generate->scheme_type != PGenerate::GS_CASE), function
  pform_endgenerate`). Confirmed independently: slang also rejects the
  construct (`error: qualifiers are not allowed on out-of-block method
  definitions`), confirming Icarus's *rejection* was already correct —
  only the diagnostic's quality (opaque `syntax error`) and the crash
  were real problems. Real, unmodified OpenTitan RTL
  (`hw/ip/spi_device/pre_dv/tb/spid_upload_tb.sv`) hits this directly:
  four `static task` declarations at module scope
  (`host()`/`sw()`/`read_sram()`/`read_sram_wrap()`, lines 186/293/624/
  663).
- **Empirically validated before implementing:** patched a local
  scratch copy of the real file (never the tracked OpenTitan source),
  removing just the word `static` from all four declarations, and
  confirmed the crash disappeared entirely (clean, ordinary
  diagnostics only) — direct evidence the `static`-triggered syntax
  error, not something else in the file, was the true trigger, before
  investing in a grammar change.
- **Root cause:** `parse.y`'s qualifier-prefixed task/function forms
  (`K_pure`/`K_extern`/`K_virtual`/`K_static`/`K_local`/`K_protected`
  combinations) are reachable *only* from `class_item` — there is no
  `module_item` alternative anywhere that accepts a qualifier keyword
  before `K_task`/`K_function`. The ordinary module-scope form
  (`K_task lifetime_opt IDENTIFIER ...`) puts the optional lifetime
  keyword *after* `K_task` (`task automatic foo();`), not before. A
  bare `K_static`/`K_automatic` token in `module_item` context
  therefore matches no rule at all, forcing bison into genuine
  panic-mode recovery from the very first token — a fundamentally
  different (and far more disruptive) failure mode than an ordinary
  semantic rejection.
- **Fix:** added four new `module_item` alternatives —
  `K_static task_declaration`, `K_static function_declaration`,
  `K_automatic task_declaration`, `K_automatic function_declaration` —
  that accept the illegal qualifier *syntactically* (reusing the
  existing `task_declaration`/`function_declaration` nonterminals
  wholesale, exactly as the already-working, already-correct
  `class_item_qualifier_opt task_declaration` class-method form does)
  and then report a specific, focused error in the trailing action
  (`error_count += 1`). The construct is still rejected — not accepted
  as valid — but through Icarus's ordinary error-reporting path
  instead of bison's unmatched-token panic-mode recovery, so no
  parser-state corruption occurs.
- **Bison grammar-safety check:** shift/reduce conflicts rose from the
  `main` baseline of 562 to 572 (+10, one pair of new alternatives per
  qualifier/declaration-kind combination); reduce/reduce unchanged at
  1122. Confirmed the three pre-existing "rule useless in parser due to
  conflicts" warnings are identical before and after (same three
  locations, unrelated to this change) — no new dead rule was
  introduced. Validated the conflict increase is benign empirically
  (per `[[parse-y-conflict-totals-are-insufficient]]`, totals alone are
  not proof): the full six-gate suite is clean, and targeted reducers
  confirm every legitimate qualifier form still works — class-scope
  `static`/`virtual`/`local static` methods, and module-scope `task
  automatic`/`function automatic` (lifetime *after* the keyword).
- **Permanent regression:**
  `ivtest/ivltests/sv_static_qualifier_module_task_fail.v` (CE — the
  minimal illegal-construct case), registered in
  `ivtest/regress-sv.list`.
- **Validation:** focused 1/1 pass, plus the class/module legitimate-
  usage reducers above (no dedicated ivtest entries needed — existing
  suite coverage of ordinary class methods and `task automatic` already
  exercises these paths, confirmed unaffected by the full sweep). Full
  `.github/ivtest_gate.sh` sweep: `Total=5826, Passed=5821, Failed=0,
  Not Implemented=2, Expected Fail=3`, name-diff gate clean (0
  unexplained). Bundled VPI suite: 108/108. Negative suite: 148/148.
  UVM regression: 357 passed, 0 failed, 0 skipped.
- **Real-world confirmation:** the exact originally-crashing
  `lowrisc:dv:spid_upload_sim:0.1` (`runtime` lane, via the full
  fusesoc/census pipeline, not just a standalone compile) no longer
  crashes — exits with a normal nonzero status and exactly 4 clean,
  specific diagnostics (one per `static task` declaration in the real
  file), matching the number of real illegal constructs present. Not
  claimed as closing this target to `PASS`; the file's own use of the
  illegal construct is a genuine (if minor) upstream issue outside this
  fix's scope — only the crash is closed.


## September 20 review baseline and next compiler batch

DD-040, DD-042 and DD-043 were reopened after their positive-only PR tests
missed selector evaluation, coverage value-tuple, and selector-resolution
failures. Selected local repairs and regression fixtures are described in
the [revision-scoped review record](session_logs/2026-09-20_pr_review_repairs.md).
The operational phases, pending gates and publication state remain in
[ACTIVE_WORK](../../.ai/ACTIVE_WORK.yaml) and [CAMPAIGN](../../.ai/CAMPAIGN.yaml).
The [restored baseline qualification](session_logs/2026-09-20_restored_baseline_qualification.json) records completed local gates.
The [recursive cross-with implementation](session_logs/2026-09-20_recursive_cross_with.md) has focused validation pending its batch gate; explicit matches remains unsupported;
DD-044 separately records constraint-body translation that drops a requested
constraint and is not closed by selector validation.

IBEX-ROW-ASYNC-RESET-SYNTHESIS has [focused and neighboring runtime evidence](session_logs/2026-09-21_row_async_reset.json); required batch gates remain pending. Ordinary blocking-index dataflow is separate recorded debt.

The [synthesis and wide-index focused checkpoint](session_logs/2026-09-21_synthesis_and_wide_index_focus.json) records paired-edition runtime and neighboring-test evidence. Required broad batch gates remain pending.

The [September 21 local batch qualification](session_logs/2026-09-21_compiler_batch_qualification.json) records the completed regression gates for the documented batch subsets at `8ab943352`. Earlier pending-gate notes describe their dated checkpoints. Overall language and UVM support remain PARTIAL; publication CI is pending.

CONSTRAINT-OBJECT-METHOD-RECEIVER is implemented and focused-tested;
required broad batch gates remain pending. Scope, indexed-receiver limits and
application failures are recorded in the [receiver evidence](session_logs/2026-09-21_constraint_object_method_receiver.json).

ENUM-NAME-BARE-CONCAT-TYPE has [focused paired evidence](session_logs/2026-09-21_enum_bare_name_type.json), with required broad batch gates pending.

SELF-PACKAGE-TYPE-CAST and SIGNED-COVER-BINS-CROSS-ZERO are focused-tested, with required batch gates pending. The [self-package cast repair](session_logs/2026-09-21_self_package_type_cast.json) and [signed coverage range repair](session_logs/2026-09-21_signed_cover_range_resolution.json) have paired focused evidence. Required broad batch gates remain pending.

The [pwrmgr follow-up reducers](session_logs/2026-09-21_pwrmgr_followup_blockers.json) confirm missing indexed packed VPI handles and skipped compound virtual-interface edge waits. These remain open; current selection and ownership are in ACTIVE_WORK.

VARIABLE-OUTPUT-PORT-DIRECTION is reproduced in both editions: external net resolution feeds back into an output variable across a collapsed port. See the [runtime reducer and net/variable controls](session_logs/2026-09-21_variable_output_port_direction.json). The directional port fix is now integrated and focused-tested; see the [installed six-fix evidence](session_logs/2026-09-21_shared_six_focus.json). Broad gates and fresh pwrmgr replay remain pending.

VPI-PACKED-ELEMENT-ACCESS is focused-tested with permanent paired-edition regressions and the affected VPI suite. See [integration evidence and remaining boundaries](session_logs/2026-09-21_packed_vpi_integration.json). Required batch gates remain pending; this is not whole-VPI or application qualification.

CONTINUOUS-STRING-ASSIGN is reproduced in both editions from the unchanged stable Caliptra/Adams Bridge rejection-sampling testbench. The [paired runtime failure](session_logs/2026-09-21_caliptra_continuous_string.json) now has an integrated, focused-tested fix; see [installed evidence](session_logs/2026-09-21_shared_six_focus.json). Broad gates remain pending. Caliptra rejection sampling still has a separately recorded testbench race; fixing string semantics does not establish application success.

### September21 constraint division/remainder by zero

CONSTRAINT-DIVMOD-ZERO is implemented and focused-tested, awaiting required batch gates. Active zero divisors produce constraint evaluation errors; guarded inactive branches remain legal. See [paired evidence and rollback tests](session_logs/2026-09-21_constraint_divmod_zero.json).

### September21 joint ordering with active cyclic variables

JOINT-ORDERED-ACTIVE-RANDC is implemented and focused-tested, pending batch gates. DD-001/Z01 no longer blanket-rejects ordinary ordering alongside cyclic variables. Multiple coupled ordinary distributions in a cyclic component remain open. See [evidence and limits](session_logs/2026-09-21_joint_ordered_randc.json).

The [packed-VPI synthesis regression repair](session_logs/2026-09-21_packed_vpi_synthesis_regression.json) passes paired runtime controls and focused synthesis/VPI suites; required broad rerun remains pending. This repairs VPI-PACKED-ELEMENT-ACCESS and adds no feature count.

The [nine-fix batch qualification](session_logs/2026-09-21_nine_fix_batch_qualification.json) completes required local gates for the integrated September21 fixes through `c1635efe9`. Broader clause/application blockers and private candidates remain open; CI/publication tracked in CAMPAIGN.

### September 21 application foundation batch

COMPOUND-VIF-EDGE-EVENTS, JOINT-ORDERED-RANDC-MULTIDIST, DV-RUNTIME-ROOT-SEED, UVM-STRICT-REGEX-GLOB-FALLBACK, CONTINUOUS-STRING-ASSIGN, and VARIABLE-OUTPUT-PORT-DIRECTION are integrated and FOCUSED_TESTED. The [installed evidence](session_logs/2026-09-21_shared_six_focus.json) owns current results and scope. Required broad gates and fresh pinned application replay are pending; these items are not yet DONE.

The [six-fix broad gate](session_logs/2026-09-21_shared_six_gate_failure.json) found regressions in automatic events and port/synthesis behavior; these are active repair obligations before qualification. The [fresh release replay](session_logs/2026-09-21_shared_six_release_retest.json) advances pwrmgr past its old HDL-path fatal to legacy regex/build errors. OpenTitan crossbar and Caliptra power2round pass their bounded checks; GPIO, pwrmgr and rejection sampling remain failing.

At `1d7e38ce5`, [runtime and startup repairs](session_logs/2026-09-21_event_runtime_regression_repair.json) have focused evidence. COMPOUND-VIF-EDGE-EVENTS remains open for synthesis boundary repairs and complete regression requalification. These repairs add no feature count.

The [private regex attribution](session_logs/2026-09-21_opentitan_regex_attribution.json) identifies the remaining GPIO/pwrmgr startup failure as a pinned application/API usage compatibility blocker. Keep application sources untouched and strict matching intact; no additional compiler implementation is selected from this observation.

PR309 required local requalification now passes on `09316da3d`; see the [revision-scoped gate record](session_logs/2026-09-21_pr309_local_qualification.json). The six-fix batch and its regression repairs await exact-head CI. OpenTitan/Caliptra residual failures remain open; local regression completion does not close those application objectives.

### September 21 descendant VIF event context

OT-PWRMGR-DESCENDANT-VIF-CONTEXT is LOCALLY_REGRESSION_TESTED, with permanent paired regressions and preserved genuine-null rejection. [Evidence](session_logs/2026-09-21_pwrmgr_descendant_vif_focus.json) records removal of the unmodified power-manager time-zero false-null failure; its configured phase timeout and distribution debt remain open. The subsequent [distribution batch](session_logs/2026-09-21_exact_large_dist_focus.json) passed the required broad local gates with this runtime fix included.

### OT-GPIO-EXACT-LARGE-DIST-RANGES — local regression validated

Exact interval sampling replaces the large ground-range weighted-soft fallback for isolated integral subjects and provably singleton expressions. Unsupported coupled/non-singleton cases fail explicitly. [Revision-scoped evidence](session_logs/2026-09-21_exact_large_dist_focus.json) records boundaries, compatibility validation, and GPIO traffic with matched responses. All required local gates passed. GPIO warnings were assessed as valid upstream NBA diagnostics and standards-permitted input coercion; they remain visible. This is not full DV-suite qualification.

### OT-PWRMGR-LOCAL-VECTOR-CLASS-INDEX-EVENT — locally regression-tested, publication pending

IEEE 1800-2017/2023 §9.4.2: `@(local_vector[cfg.index])` missed local-vector changes because class-mutation lowering omitted the ordinary dependency. Synchronous combined registration fixed arming, but a deferred value filter still lost same-slot pulses. The current patch evaluates the complete expression at occurrence time using the existing VVP evaluator, captures selectors/owners once in their original evaluation order, refreshes precise subscriptions on equal values, and schedules the original process only on a value change. Cancellation, context isolation and Reactive arming have focused regressions. [Current revision-scoped evidence](session_logs/2026-09-21_occurrence_event_focus.json) owns results and remaining gates; [candidate1 evidence](session_logs/2026-09-21_mixed_event_focus.json) preserves the earlier failure. All required local gates pass; publication is pending. The unmodified pwrmgr seed3 assertion remains separately recorded debt; no application workaround is selected.

### OT-PWRMGR-SEED3-ESC-TIMEOUT — valid seed; upstream checker defect confirmed

- **State:** Minimal checker correction validated in a separate overlay; pristine-release failure remains visible.
- **Evidence:** [Current revalidation](session_logs/2026-09-21_pwrmgr_seed3_upstream_revalidation.json) records valid randomized clock phases, fresh positive/negative checks and seed replays. [Original signal trace](session_logs/2026-09-21_pwrmgr_seed3_phase_assessment.json) and [earlier correction](session_logs/2026-09-21_pwrmgr_seed3_checker_fix.json) remain historical evidence.
- **Upstream confirmation:** [OpenTitan PR28474](https://github.com/lowRISC/opentitan/pull/28474) fixes this exact sampled-clock failure. Its subsequent port-connection correction is required when evaluating that backport. No VCS differential or VCS-specific defect is established.
- **Boundary:** User authorizes necessary downstream repair. Preserve the pristine stable corpus and report checker-overlay runs separately. The minimal activity correction retains the original assertion contract. The stronger official heartbeat/`until` backport passes smoke but exposes a separate continuation negative-test failure requiring investigation before full validation.

### OT-WHOLE-FUNCTION-CLASS-EVENT — class-method event dependencies

- **State:** REGRESSION_TESTED; required local gates pass for the documented integral-expression subset. [PR #317](https://github.com/dsellerbrock/iverilog-uvm/pull/317) merged after Ubuntu 24.04 CI passed; remaining platform CI was pending at merge.
- **Semantics:** IEEE 1800-2017/2023 §9.4.2 integral event expressions and class method receivers.
- **Evidence:** [Revision-scoped implementation and focused results](session_logs/2026-09-21_whole_function_event_focus.json), including retained baseline failures. Virtual-interface reads inside methods remain explicitly unsupported.
- **Closure:** Correct value-change behavior, ordinary dependency tracking, receiver lifetime/rebinding, unchanged-value suppression and required regression gates. Reuse the existing expression observer; no source workaround.

### OT-SPI-COMPOUND-EVENT-LIST — atomic class-property event lists

- **State:** REGRESSION_TESTED local checkpoint; permanent and mapped UVM gates pass. Broad suites remain at the authorized batch checkpoint; no full qualification claim.
- **Semantics:** IEEE 1800-2017/2023 §9.4.2, pure integral event lists containing class-property reads.
- **Evidence:** [Scoped implementation and validation](session_logs/2026-09-21_spi_class_event_list_focus.json).
- **Application boundary:** Pristine M6 SPI Host advances past this event-list diagnostic but still fails compilation; queue type diagnostics and a selected-event synthesis crash remain.

### OT-SPI-SELECTED-VIF-EDGE — selected virtual-interface edge expressions

- **Status:** REGRESSION_TESTED; all required local gates pass; publication/CI pending.
- **Requirement:** IEEE 1800-2017/2023 9.4.2 and 25.9. Evaluate the complete selected expression with live receiver/index dependencies and the four-state edge table; cancel all registrations on wake/kill.
- **Root cause:** Structural synthesis received a class-property selector without a signal net. The candidate routes selected edge expressions through the synchronous observer and subscribes to actual VIF signal reads.
- **Evidence and qualification:** [Revision-scoped record](session_logs/2026-09-21_selected_vif_edge_focus.json). Pristine stable SPI compilation advances to explicit queue/constraint diagnostics; no SPI DV pass.

### CI-WIN-UVM-REGEX-NOOUTPUT — strict-regex test crashes under MSYS2 TRE regex

- **Status:** DONE. Merged in PR321 (`3ccd5d73`) after all six CI jobs passed; MINGW64/UCRT64/CLANG64 report `uvm_regex_strict_exec_test PASS` and UVM 358/358.
- **Observation:** Every MSYS2 job since merged PR317 fails `uvm_regex_strict_exec_test` with no captured output; Linux and macOS pass.
- **Root cause:** Vendored `uvm_re_comp` calls `regfree` on a `regex_t` whose `regcomp` failed. POSIX leaves that undefined; TRE (libsystre) segfaults on the test's first invalid pattern. TRE also rejects legal 2048-character patterns with REG_ESPACE when submatch tracking is on.
- **Fix:** The fork-owned wrapper skips `regfree` for exactly the buffer that failed to compile. It adds `REG_NOSUB`, which leaves every match result unchanged because the vendored `regexec` passes `nmatch=0`. The UVM runner now reports the vvp exit status for no-output failures. Pinned UVM sources are unchanged.
- **Evidence:** [Revision-scoped record](session_logs/2026-09-22_win_regex_tre_fix.json); Linux TRE reproducer `evidence/win-regex-tre/`.

### SVA-IMPLICATION-UNTIL-CONTINUATION — locally regression-tested; merged in PR319 (`288132f2`)

The upstream OpenTitan checker backport exposed missed late `until` violations. The compiler correction covers property truth, empty/nonempty repetition concatenation and independent consequent timing. [Revision-scoped evidence](session_logs/2026-09-21_until_continuation_focus.json) owns the exact subset, tests and pending gates. This does not qualify the pristine application or the complete assertion language.

### OT-SPI-INLINE-CALLER-QUEUE-FOREACH — locally regression-tested

Direct caller-owned integral queue/dynamic-array iteration now has paired focused evidence, including target-first lookup, signed values, invalid-state rejection and rollback. The pristine SPI compile no longer rejects this foreach; independent errors remain. [Revision-scoped evidence](session_logs/2026-09-22_caller_queue_foreach_focus.json) owns results and passing required local gates. Merged in PR320 (`1af223c8`); Linux/macOS CI jobs passed on the preceding main run, and the MSYS2 failure is CI-WIN-UVM-REGEX-NOOUTPUT. No full application qualification is claimed.

### OT-SPI-INLINE-STATE-FUNCTION-CALL — merged state-only scope

- **Status:** State-only scope merged in PR323; staged random-variable arguments remain open.
- **Requirement:** IEEE 1800-2017 §18.5.12 / 2023 §18.5.11 function calls in inline randomize constraints, with §18.7 call semantics.
- **Evidence:** [Revision-scoped focused record](session_logs/2026-09-23_inline_state_function_focus.json). The bounded state-only caller/target/self path preserves post-`pre_randomize` state, four-state rejection, virtual dispatch, and retained target identity. The record lists remaining argument and width limits; no complete clause or SPI DV qualification is claimed.

### OT-SPI-INLINE-CALLER-OBJECT-METHOD — caller-scope object methods in inline constraints

- **Status:** RECONCILED during direct-main integration after PR323. PR322 closed without merging. Its earlier implementation (`ce2635bd`) captured the call before OT-SPI-INLINE-STATE-FUNCTION-CALL's guarded caller capture and bypassed null-receiver, X/Z, purity/direction and width checks, so it was omitted. Retained caller-method tests pass against PR323's guarded source; the extra collision and boundary regressions merged in PR324 (`ea0be16d5`). The record below is PR322's historical state (REGRESSION_TESTED locally at `ce2635bd`).
- **Requirement:** IEEE 1800-2017 18.5.12/18.7 and 1800-2023 18.5.11/18.7. Inline names resolve target-first, then in the caller. A function in a constraint is called before solving, and its result is a state value.
- **Reproducer:** pristine Earlgrey-PROD-M6 `spi_device_cmd_rsp_seq.sv:117` (`num_lanes == cfg.get_sio_size()`) and `evidence/inline-caller-method/caller_method.sv`. Both editions reported "could not be translated".
- **Root cause:** Object-method state capture existed only for declared class constraints (`constraint_ir_state_calls_ctx_`). Inline caller-scope method calls had no lowering.
- **Historical PR322 fix:** Captured a caller call as a value slot before the guarded lowering; this code was removed. The current guarded state-function path also handles target-member receivers and rejects invalid null/X/Z captures. Indexed receiver calls remain unsupported.
- **Evidence:** [PR322's revision-scoped record](session_logs/2026-09-22_inline_caller_object_method.json) is historical; the [local qualification](session_logs/2026-09-23_pr322_reconciliation.json) and [branch reconciliation](session_logs/2026-09-23_pr322_branch_reconciliation.json) own the current limits. No DV claim.

### VVP-EXTENDED-ARGS-GLIBC-PERMUTE — vvp extended arguments parsed as options on glibc

- **Status:** Committed directly to `main` as `3505e15a6`; CI pending on that main revision.
- **Authority:** `Documentation/usage/vvp_flags.rst` (Extended Arguments) and `vvp.man`: options precede the design file; everything after it is an extended argument.
- **Root cause:** `vvp/main.cc` dropped upstream's leading `+` from the getopt string, so glibc permutation parsed post-file arguments such as `-vcd`/`-none` as vvp options. JSON tests `br_gh710a/b/c`, `dumpfile` and `sdf_header` failed on Linux; macOS getopt hides this.
- **Fix:** Parse options in order and set aside `+plusargs` that precede the options (dvsim ordering) until the input file. The simulation then sees the file, all plusargs in command-line order, then the extended arguments.
- **Evidence:** [Revision-scoped record](session_logs/2026-09-22_vvp_extended_args.json); new permanent JSON test `vvp_plusarg_order`.

### CONSTRAINT-UNIFORM-LEGAL-COMBINATIONS — unordered solutions are not uniform

- **Status:** REPRODUCED; not selected. Risk is CRITICAL because it touches core solver sampling architecture.
- **Requirement:** IEEE 1800-2017 18.5.10 / 1800-2023 18.5.9: "The solver shall assure that the random values are selected to give a uniform value distribution over legal value combinations."
- **Reproducer:** `evidence/solve-before-array/ieee_table_18_2_uniformity.sv`, the standard's class B (`s -> d == 0`, 32-bit `d`). The current build gives `s == 1` in 251 of 1000 unordered draws, where IEEE expects about 1/(1+2^32). With `solve s before d` it gives 489 of 1000, matching Table 18-2. The same bias appears with dynamic arrays (103 of 400 against about 0).
- **Root cause (assessed):** exact joint enumeration (`z3_enumerate_joint_`) is used only for bounded coupled components with distributions or ordering. The default path steers Z3 optimize toward random soft targets per variable, which gives per-variable diversity but not uniform complete combinations.
- **Closure bar:** uniform sampling over legal combinations for coupled components beyond the enumeration cap (for example exact counting per case split, or a proven uniform-hashing sampler), paired statistical oracles, deterministic seeds, unchanged RNG ownership. Raising the enumeration cap is not a fix.

### SOLVE-BEFORE-FIXED-ARRAY — whole fixed rand arrays in solve...before

- **Status:** Core expansion committed directly to `main` as `bea0a4db3`; the non-integral element guard is locally qualified on the follow-up branch, with CI pending.
- **Fix:** A whole 1-D fixed array (class property or unpacked-struct member) expands to its elements. Non-rand arrays are diagnosed and multidimensional whole arrays are a loud sorry on main. The follow-up diagnoses non-integral elements, including class handles, instead of fabricating order tokens. The original [PR322 record](session_logs/2026-09-22_solve_before_fixed_array.json) is superseded for that guard by the [local qualification](session_logs/2026-09-23_pr322_reconciliation.json) and [branch reconciliation](session_logs/2026-09-23_pr322_branch_reconciliation.json). IEEE 1800-2023 real ordering remains separate debt.

### DPI-EXPORT-DROPPED-EXIT-STATUS — unsupported DPI export dropped with exit 0

- **Status:** Committed directly to `main` as `c7b2a8267`; local regressions pass and main CI is separate.
- **Root cause:** `tgt-vvp/vvp_scope.c` reports `sorry: ... The export is dropped` but did not count an error, so code generation succeeded. The negative tests passed in CI only because a non-root user cannot create `/dev/null.dpiexport.c`.
- **Fix:** Count the dropped export in `vvp_errors`. The existing negative tests `m10_dpi_export_class_handle_argument` and `m10_dpi_export_open_array_argument` now pass independently of the environment.
