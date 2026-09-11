# Discovered debt (parking lot)

This file exists so that finding a defect while working a different
`.ai/ACTIVE_WORK.yaml` ticket never becomes an excuse to widen that ticket.

**Recording an unrelated discovery completes the active agent's
responsibility for it during the current ticket.** Do not fix it, do not
investigate it further, do not expand scope to cover it. Record it below and
return to the active work item.

Triage (promoting an entry here into `docs/conformance/BLOCKERS.md`, or
opening a new `.ai/ACTIVE_WORK.yaml` ticket for it) is a separate activity
done outside any single targeted-fix run.

## Entry format

```markdown
### DD-<NNN> — <short observation>

- **Discovered while working:** <active blocker ID, or "governance
  bootstrap" / other non-blocker task>
- **Observation:** <what was seen>
- **File/function:** <path:line or symbol, if known>
- **Possible clause:** <IEEE clause if applicable, else N/A>
- **Evidence:** <how it was noticed — log excerpt, source read, etc.>
- **Reproducer status:** none / sketched / confirmed
- **Triage status:** untriaged / promoted to BLOCKERS.md as <ID> / declined (why)
```

---

No entries yet. This governance-bootstrap pass did not investigate
implementation code for defects (that would itself be an audit, which is
out of scope here) — nothing was discovered during this ticket that
requires parking. Use the format above for the next agent's discoveries.


### DD-001 — joint active-randc prepass and enumeration-cap interaction

- **Discovered while working:** Z01A
- **Observation:** Source review found a randc draw before complete component enumeration. A draw-dependent over-cap failure could condition successful calls on the selected value; not reproduced or claimed as a confirmed defect.
- **File/function:** vvp/vvp_z3.cc, z3_solve_pass_ randc prepass and exact_joint component enumeration.
- **Possible clause:** IEEE 1800-2017 18.4.2 / global constraint distributions; exact applicability needs triage.
- **Evidence:** Independent Z01A source review; ordered active-randc is explicitly excluded/rejected by Z01A.
- **Reproducer status:** sketched
- **Triage status:** untriaged


### DD-002 — associative member foreach loses string key type

- **Discovered while working:** L01
- **Observation:** foreach(boxes[selector].values[key]) with class member values[string] declares key as int and iterates zero entries. Same output and int key declaration with retained pre-L01 compiler and campaign runtime; not caused by the selected-prefix fix.
- **File/function:** pform_make_foreach_declarations / foreach_index_type_t unindexed member type resolution.
- **Possible clause:** IEEE 1800-2017/2023 12.7.3 implicit index type.
- **Evidence:** evidence/campaign-20260908/l01/typed*.sv, .vvp and logs; old compiler from preserved string-array-param-after253 worktree, a diagnostic comparison rather than a campaign qualification gate.
- **Reproducer status:** confirmed
- **Triage status:** resolved within the reviewed, locally validated L05 selected-member index-type scope; no repair included in L01. Broader container/header validation remains separate.

### DD-003 — Boolean event-expression driver discards automatic activation context

- Active blocker: L02. Record-only; not a regression from L02.
- Observation: simultaneous task activations using posedge (value[2] | 1'b0)
  both report transition time 2 instead of 2,3.
- Mechanism: vvp/logic.cc vvp_fun_boolean_ receives no retained context and
  vvp_fun_or::run_run sends its result with context 0; input storage is shared.
- Authority: IEEE 1800-2017/2023 6.21 and 9.4.2; expression event transition
  must use the invocation's value.
- Evidence: u01-loop/history-expression-preexisting.sv, history-baseline.log,
  history-baseline.vvp; fresh e0dab7221 compiler rebuilt into baseline-tools
  with original frame selection. Identical 2,2 failure on baseline and L02.
- Reproducer status: resolved within reviewed locally validated L03 Boolean
  functor family and supported input chains. Other expression families remain
  unqualified; no general expression-correctness claim.

### DD-004 — Unchanged partial write can manufacture a default-bit negedge

- Active blocker: L02; record-only, not introduced by frame selection.
- Observation: default bit vector 0, unchanged value[2:1]=0 at t1 wakes
  negedge value[0], although the intended first negedge is at t3.
- Mechanism: vvp_fun_signal4_aa::reset_instance emits no initial sample;
  recv_vec4_pv sends even an unchanged vector, exposing probe history X.
- Authority: IEEE 1800-2017/2023 6.8 and 9.4.2.
- Evidence: u01-loop/default-negedge.sv and baseline/candidate logs, both
  fail at t1. Original e0dab7221 compiler frame layout also fails with the
  candidate runtime; native probe path has no ancestor history to seed.
- Reproducer status: resolved within L04 reviewed locally validated automatic integral default publication. Broader types and derived Boolean contexts remain unqualified.

### DD-005 — Non-fanout assertion paths omit vacuous user pass actions

- Active blocker: S03; record-only outside the endpoint aggregation path.
- Observation: `tests/sva_recursive_consequent_test.sv` executes17 enabled
  starts; the fixed negated consequence has one nonvacuous success and one
  failure, but reports only1pass rather than16 including vacuity. Existing
  until/eventual controls similarly count only nonvacuous successes.
- Mechanism: unchanged non-endpoint NFA/legacy implication handling suppresses
  vacuous pass dispatch. S03 repairs only the split endpoint parent path.
- Authority: IEEE1800-2017/2023 16.12.7; a no-match antecedent succeeds.
- Evidence: campaign-20260908/s03/recursive-red-2017.log and2023.log;
  old baseline test already expects1pass, and the unaffected source path
  omits its vacuous action. Nested/throughout parent paths now report17.
- Reproducer status: observed in both editions; triage pending. Do not infer
  general vacuity qualification from the S03 endpoint-path controls.

### DD-006 — nested parameterized sequence alias does not expand

- **Discovered while working:** S04.
- **Observation:** Pair(x,y) defined as x ##2 y works when reused directly with distinct actuals in OR/AND antecedents. Wrapping Pair(a,b) and Pair(c,d) in named Left/Right aliases instead reports No function named Pair during elaboration.
- **File/function:** pform.cc sequence splicing / parameter-window antecedent normalization; causal triage pending.
- **Possible clause:** IEEE 1800-2017/2023 sequence declarations and argument binding; exact clause pending triage.
- **Evidence:** evidence/campaign-20260908/s04/window-nested-alias.sv and window-nested-alias.log. Same four errors with compiler rebuilt from validated61ca5f336: window-nested-baseline.log. Current source/build restored afterwards; installed candidate tools unchanged during running gates.
- **Reproducer status:** confirmed before S04; direct parameterized reuse is a passing control.
- **Triage status:** resolved within S07 reviewed locally validated bare-alias recursive expansion scope; full dependency-graph validation and broader parameterized declaration lookup remain unqualified.

### DD-007 — symbolic repetition still reports consequent endpoint verdicts

- **Discovered while working:** S04 oracle review.
- **Observation:** Symbolic ranged/unbounded antecedent lowering retains per-endpoint consequent pass/fail actions, rather than aggregating one parent assertion verdict. S03 repaired the NFA parent model, not this separate symbolic engine. S04 only repairs previously missing vacuity for ages that never matched.
- **File/function:** pform.cc sva_parameter_repeat_try_assertion_ r_pass_req/r_fail_req and endpoint counts.
- **Possible clause:** IEEE 1800-2017/2023 16.12.7 and 16.14.1.
- **Evidence:** Existing validated sv_assert_repeat_parameter_override and sv_assert_repeat_parameter_smoke tests explicitly expected multiple endpoint actions before S04. Independent S04 review derived their new totals by adding vacuity; these remain compatibility checks, not per-attempt standards qualification. No new regression inferred from those totals.
- **Reproducer status:** existing regression stimuli retained; parent-verdict reducer needs a deliberate selection boundary.
- **Triage status:** resolved within S05 locally validated fixed ##0/##1 symbolic repetition scope. Broader symbolic consequent-delay overrides remain DD-008 and are not covered by this qualification.

### DD-008 — symbolic consequent delay override uses the default

- **Discovered while working:** S05 boundary reducer construction.
- **Observation:** `a[*LO:HI] |-> ##D q` with defaults LO1/HI2/D0 and instance D1 passes at the second tick instead of awaiting the final child at tick3; making q false at tick3 produces no failure. Explicit literal ##1 is a passing control in the S05 paired reducers.
- **File/function:** pform.cc cycle-delay normalization and symbolic repetition probe; causal triage pending.
- **Possible clause:** IEEE1800-2017/2023 6.20.2,16.9,16.12.7; exact delay-normalization cause unverified.
- **Evidence:** campaign-20260908/s05/parameter-delay-override.sv and .log; current candidate produces EARLY1/0 then1/0. First observed before the S05 parent edit; no retained pre-S05 isolated reducer result, so baseline comparison remains required.
- **Reproducer status:** reduced current failure; literal-delay control passes.
- **Triage status:** resolved within the reviewed, locally validated S06 single named parameter/localparam delay scope. Broader delay-expression syntax, composed/multiclock shapes, formal lookup and maximal-width arithmetic remain unqualified.


### DD-009 — Invalid foreach header selector accepts an implicit string key

- **Discovered while working:** L05
- **Observation:** foreach(boxes[key].values[key]) where boxes is fixed-size
  and values is string-keyed compiles despite the implicit key being string.
  The attempted outer-key positive interpretation was withdrawn after IEEE
  12.7.1/12.7.3 review; both Slang editions reject the string selector.
- **File/function:** Selected target expression/index type validation; not
  isolated to a specific lower-level check yet.
- **Possible clause:** IEEE1800-2017/2023 7.4.2,12.7.1,12.7.3.
- **Evidence:** campaign-20260908/l05/shadow-invalid-positive.sv and design
  review. Existing runtime target binding was preserved, not changed to
  make this invalid positive case pass.
- **Reproducer status:** Candidate acceptance observed; exact diagnostic
  reducer and pre-existing validation mechanism remain to be isolated.
- **Triage status:** record-only; no repair or invalid-header qualification
  is included in L05's legal selected-member index-type increment.

### DD-010 — Uninstantiated merged covergroup type enters overall denominator

- **Discovered while working:** V06 final scope-control review.
- **Observation:** One fully covered instantiated type plus a declared but
  uninstantiated merged type produces overall50 rather than100 percent.
- **File/function:** vvp/class_type.cc type_coverage/registry eligibility and
  vvp/vthread.cc of_COVGRP_GET_ALL; exact correction not yet selected.
- **Possible clause:** IEEE1800-2017/2023 19.9,19.11,19.11.3; complete eligibility
  semantics require review at selection.
- **Evidence:** campaign-20260908/v06/uninstantiated-type.sv and candidate/v05
  logs. Both candidate and saved validated V05 runtime reproduce50 vs100.
  For V05 compatibility only the new item-type-weight tags were removed from
  emitted bytecode; every item/type weight in this reducer is1.
- **Reproducer status:** Pre-existing runtime failure established on V05;
  no source repair or broad application qualification inferred.
- **Triage status:** record-only during V06. V06 function-scope test instantiates
  all intended groups before checking their weighted aggregate; its bin/type
  weight assertions remain explicit and independently checked.

- **DD-010 resolution:** V07 locally validates the shared population guard with
  paired lifecycle controls and full required local gates. Never-instantiated
  types are excluded; zero-weight retired merged instances remain represented.
  Remote CI and broader coverage qualification remain separate.


### DD-011 — UVM release-matrix compile frontiers

- **Discovered while working:** U02 user-requested release acquisition/probes.
- **Evidence:** `docs/conformance/uvm_release_matrix.md` and local
  `third_party/uvm-releases/results-pv87b5yu/results.json`; unmodified releases,
  compiler/runtime implementation03caa64c8, actual-g2012.
- **Observed:** Legacy1.x/2017 libraries encounter member-delay syntax (1.0p1
  also reports process class lookup);2020.1.0/1.1 encounter nested resource
  queue type/assignment errors;2020.3.2 rejects default-initialized unpacked
  struct queue `accesses` in uvm_reg_map.svh2058. Later diagnostics may cascade.
- **Classification:** Reproduced compile gaps, not yet reduced/standards-classified.
  Do not label nonstandard library syntax a mandatory IEEE compiler defect.
- **Triage:** Record-only during U02; select and ground one causal mechanism
  before any semantic fix. No archived library or application source patched.


- **L08 candidate follow-up:** Original2020.1.0/1.1 now compile at47e6c87b3, but both are RUNTIME_FAIL in results-gizcr5j0 (complete=true,baseline_valid=true). Runtime logs report unresolved uvm_re_match/uvm_glob_to_re DPI symbols followed by command-line UVM errors and BUILDERR. Record-only pending L08 validation; release-specific DPI loading/ABI and runtime semantics are not qualified. No library edits.


### DD-012 — L06 mixed-array and class-qualified declaration boundaries

- **Discovered while working:** L06 expanded initialization controls.
- **Evidence:** evidence/campaign-20260908/l06/class-qualified-module-declaration.sv
  and queue-of-fixed-array.sv plus compile logs; no fixes included.
- **Observed:** Module-level class-qualified declarations hit parser errors;
  the supported procedural class-qualified form is covered positively. Queues
  of fixed-array elements hit the existing netuarray_t unsupported boundary.
- **Triage:** Record-only. Permanent array boundary tests guard against wrong
  dimension classification but do not qualify those legal unimplemented shapes.

### DD-013 — Last-element queue lvalue crashes elaboration

- **Discovered while working:** L06 officialUVM2020.3.2 replay after queue-default fix.
- **Evidence:** UVM uvm_field_op.svh112 assigns msg_queue[$]; minimal
  evidence/campaign-20260908/l06/queue-last-lvalue.sv creates stringq, pushes
  one element and assigns q[$]. Expected replacement of the last element.
- **Observed:** Saved validated03caa64c8 compiler and L06 candidate both abort
  at elab_lval.cc1335 use_sel==SEL_NONE in2017/2023. Four logs preserve proof.
- **Triage:** Proven preexisting next-blocker candidate; not caused by L06,
  not repaired in its patch. UVM2020.3.2 is still COMPILE_FAIL/unqualified.

- **L07 follow-up:** Direct queue-variable element assignment fixed and locally validated at `9a1b6beb3`. Unmodified2020.3.2 now passes the release smoke. Class-property/root-member last-index forms remain outside the resolved scope.

### DD-014 — Terminal process kill loses descendant reachability

- **Discovered while working:** U01 teardown source tracing; record-only.
- **Observation:** `of_PROCESS_KILL` returns immediately when the process has no
  owner or already reports FINISHED/KILLED. Thread reaping reparents detached
  children. This appears unable to kill live descendants through a retained
  handle to a terminated parent.
- **File/function:** `vvp/vthread.cc`, `of_PROCESS_KILL`, `vthread_reap`.
- **Possible clause:** IEEE 1800-2023 9.7 explicitly requires killing live
  descendants even when the target is FINISHED/KILLED. The 2017 wording differs
  and needs separate qualification; do not infer identical edition requirements.
- **Evidence:** Current source at validated semantic revision `9a1b6beb3` and
  local primary LRM text; no attribution to U01's intermittent warnings.
- **Reproducer status:** none.
- **Triage status:** untriaged; no implementation authorized by this entry.

### DD-015 — Function-valued UVM core-state wait diagnostic woke early

- **Discovered while working:** U01 post-report observer construction.
- **Observation:** An added diagnostic top using
  `wait (get_core_state() == UVM_CORE_FINISHED)` continued at time zero and
  stopped the application at 1 ns. This invalidated the observer attempt; it
  is not application qualification or proof of a compiler defect.
- **File/function:** `uvm-core/src/base/uvm_globals.svh`, `get_core_state`;
  evidence `u01-after-l07/teardown_observer_wait_attempt.sv` and
  `teardown-observer.log` preserve the attempt.
- **Possible clause:** Wait expression evaluation and function dependencies;
  exact applicable semantics and cause remain to be established.
- **Reproducer status:** diagnostic observation only; not minimized.
- **Triage status:** untriaged, record-only. U01 observer now uses a bounded
  explicit time after the known smoke completion and verifies log ordering.

### DD-016 — Regex edge cases during legacy ABI comparison

- **Discovered during:** U04 read-only legacy/modern regex comparison, before U05 prerequisite selection.
- **Evidence:** Modern uvm-core/src/dpi/uvm_regex.cc uvm_re_comp strips slash brackets without the legacy len>1 guard; the single-slash input appears to underflow re_len-2. Source-only, not yet reduced; do not claim a runtime defect without evidence. Legacy2020.1 glob_to_re bracketed-input branch also falls through into the tail rather than preserving input, unlike modern conversion.
- **Disposition:** Record-only; original vendor code unchanged. U04 must define explicit regex/empty/slash/bracket/error expectations before any ABI delegation; upstream behavior is not automatically normative.

### DD-017 — Original UVM2020.1 smoke exits before intended phase checks

- **Discovered during:** U04 original-release replay.
- **Evidence:** results-9mvpk_8f complete=true,baseline_valid=true; both original2020.1 releases compile0/runtime0, no unresolved DPI symbols or command-line UVM errors, but finish at time0 without required smoke completion marker. Direct legacy ABI tests pass4/4 across both releases/editions.
- **Disposition:** Record-only during U04; still RUNTIME_FAIL. Establish whether the intended run-phase traffic/checking executes and reduce the causal mechanism after the current semantic baseline is validated. No warning waivers or application edits.

U06 closes the recursive-input cause after full validation at aad6fe22b.
Original2020.1.0/1.1 now pass their unchanged smoke; full qualification remains separate.

### DD018 — Nested argument output copy-out selects staged caller scope

Discovered under U06. Evidence-only copyout_control.sv and
copyout-baseline.log/copyout-candidate.log in evidence/campaign-20260908/u06
show identical failures on validated aa172f5 runtime and U06 candidate.
A recursive method passes get_child(output seen) as an argument; seen is
an automatic caller local. Generated copy-out stores through the staged
outer callee frame instead of the caller frame. Both runs fail the output
assertion when input assertions are removed to isolate this behavior.
IEEE 1800-2017/2023 13.5 argument passing is the applicable cluster; exact
copy-out correction remains untriaged. Symbols: draw_copy_out_function_argument,
scoped write-context selection. Original smoke has no such output actual.
Record-only, not a U06 regression or a qualified subcase; preserve reducer
for deliberate selection after validating the input-context increment.

DD018 resolved by L09 at 3c44fd13b after required local validation.
Caller actual context and formal source context are now selected separately.

### DD019 — Scalar output into fixed-array class property element

L09 probe fixed_property_output.sv (evidence/campaign-20260908/l09) produces
"Skipping indexed property copy-out" on both validated U06 target and L09
candidate. Existing emitter supports certain container-valued property
elements but not this scalar fixed-array slot. Compile baseline diagnostic
is preserved in fixed-property-baseline-compile.log. Legal output lvalue
classification belongs to IEEE2017/2023 13.5 and class array properties;
implementation remains open. Record-only during L09; no warning waiver or
claim of fixed-array property-element output support.


### DD020 — Scalar output actuals evaluated before call and on return

L10 index-side-effect control fails on candidate because scalar output actuals
are copied in before function execution. Existing function_port_is_container_output_
only suppresses container/fixed-array output input evaluation. The same issue
applies to plain fixed-array scalar actuals on validated L09, independent of
L10 property stores. IEEE2017/2023 13.5 return copying; must preserve automatic
formal defaults and static output persistence. Selected prerequisite L11; L10
patch and reducers preserved under evidence/campaign-20260908/l10.

L10 receiver().slots[...] syntax probe was rejected by parser; preserved in
receiver_syntax_probe.sv. Not required for nested env.box receiver coverage;
record-only syntax frontier, no parser changes under L10.

DD020 resolved by L11 at b32df9a29 after all required local gates.


L10 conversion probes found ordinary string/integral assignments are permissively
accepted by the existing frontend despite6.16 requiring explicit casts. Preserved
`evidence/campaign-20260908/l10/string_assignment_control.sv`; broader assignment
diagnostic debt is record-only. L10 now rejects the fixed-property output
mismatch so its new typed stores cannot execute a mismatched load opcode.

DD019 resolved by L10 at051aeee8e after validatedL11 prerequisite and all required local gates.


### DD021 — UVM1.2 frontiers after member-delay parsing

U07 candidate original1.2 probe `third_party/uvm-releases/results-sv_woyjp`
gets past #setting.offset but fails elaboration: uvm_printer.svh1172 reports
an unsupported index on struct member val, and uvm_traversal.svh284-285 reports
hierarchical references to automatically allocated compiled_regex in visit.
The upstream declaration is explicitly `static chandle compiled_regex`;
reduce lifetime handling and hierarchical lookup rather than assuming the diagnostic is correct.
A uvm_sequence_base.svh1255 pick_sequence constraint item is also reported
unrepresentable and ignored. These remain separate semantic/diagnostic
frontiers; no UVM pass or waiver. Source trees unchanged; record-only during
U07, reduce/classify at a later coordinator boundary.

### DD022 — Original UVM 2017.0.9 smoke runtime timeout

U07 full release sweep `third_party/uvm-releases/results-4r1diuop`
compiles unchanged 2017.0.9 successfully, then its runtime times out after
300.059 seconds with an empty log. The earlier baseline rejected member-delay
syntax before runtime. Source hash and exact commands are preserved in results.json.
No causal runtime diagnosis yet; timeout is not proof of a scheduler defect.
2017.1.0 and 2017.1.1 now pass all smoke checks. Record-only during U07;
reduce and classify at a later coordination boundary. Full release remains open.

### DD023 — Unknown ordinary string index behavior

During L12 control testing, an ordinary string `s="@abc"` read at integer
X or Z index returns character64 for both `s[i]` and `s.getc(i)`. Negative
and length indices return0. The runtime string select reads an integer word
without its unknown flag. Evidence `evidence/campaign-20260908/l12/bounds_control.sv`.
Needs standards classification; not claimed qualified and record-only for L12.

### DD024 — String character selection loses signed byte type

L12 high-bit control shows ordinary and proposed member indexing widen0xff to255, while getc/byte cast yield-1. Both-edition6.16 and6.11.3 require signed byte. Selected as prerequisite L13; L12 partial work preserved and source restored before new baseline. Prior9baa5a9c3 gates passed, but reopened after narrow two-state parameter index2 returned0 instead of the third byte. Corrected by849a779ea with source-signed resize and separate signed int cast; all required gates pass. L12 may resume.

### DD025 — Class string-property character index uses property slot

L13 control `c.s[1]` with `c.s="abc"` aborts in class_type.cc get_string
array_size assertion on both saved L10 compiler and L13 candidate. Index0
returns whole string instead of character. Exact reducer `evidence/l13/class_control.sv`
and L12 byte_type probe retained. Distinct property dispatch defect, not
introduced by signed-byte typing; record-only, no class-property character
qualification claimed by L13.

### DD026 — Constant function string argument character result unknown

L13 `constant_probe.sv` contains automatic int function get_value(input string s)
returning s[0], evaluated for a localparam. Both saved L10 and L13 candidates
produce X for that constant-function result; direct typed parameter selection
is a distinct L13 width issue now in scope. Evidence/l13/constant_probe_results.json.
Record-only for constant-function argument/evaluation classification; no
constant-function string qualification claim.

DD023 follow-up during resumed L12: with "abcde" and a four-state integer
index ending in1x, ordinary s[idx] and initial L12 member path returned'a',
while getc(idx) returned'c'. Both editions6.16/getc(int) and6.11.2 require
per-bit two-state conversion. L12 now uses the existing int2/32 cast for its
new member path; ordinary string index lowering remains a separate proven
gap. Evidence/l12/index_conversion.sv. No ordinary-selector fix included.

### DD027 — Original UVM1.1d compiles but does not pass smoke

L12 candidatea85a256b1 removes the member-string elaboration frontier. Original1.1d now compiles with ignored-constraint and object-expression null-fallback warnings, then runtime exits0 but fails the smoke qualification checks. Evidence third_party/uvm-releases/results-qb7873zh/1.1d/{compile,runtime}.log. Runtime reports missing DPI symbol uvm_dpi_regcomp, four command-line regex UVM_ERRORs and one BUILDERR UVM_FATAL, then exits0 before smoke completion. Exit0 is not a smoke pass. Record-only during L12 required validation.

DD021 follow-up: L12 candidate removes original1.2 printer string-index errors. Four remaining compilation errors at uvm_traversal.svh284-285 concern compiled_regex in visit, plus the existing ignored pick_sequence constraint warning. Original1.1a now reaches fork/join_any-in-function and void-cast-of-void diagnostics; standards legality must be verified before selecting changes. No library edits or qualification claims.

### DD028 — Original UVM1.2 smoke runtime produces no output before timeout

L14 candidate69ff60cc6 removes all four visit.compiled_regex reference errors. Original1.2 compiles0 in0.635s, then runtime times out after300.061s with empty runtime.log (return-9). Evidence third_party/uvm-releases/results-f9qr050b/1.2 and results.json. Ignored pick_sequence constraint and newly reached object-codegen null-fallback warnings remain visible. No relationship to the already known2017.0.9 timeout is proven. Select and reduce after L14 required gates; do not infer startup, scheduler, DPI or initialization cause from an empty log alone.

### DD029 — General class method visibility fallback gaps

U08 review observed local base methods still accessible when no enclosing homonym exists, and through explicit class qualification. Existing method_from_name and later call fallbacks do not enforce complete method access control. U08 is bounded to inherited lexical precedence over enclosing homonyms; it retains qualifier metadata and prevents a package-selected statement call being re-resolved to a local base method. General no-homonym/explicit-qualified access checks remain separate qualification debt, not a completed8.18 feature.

### DD030 — Original UVM1.2 reaches missing legacy regex DPI

U08 development replay results-pqt3anxi removes the root-construction recursion and starts release_test, then reports missing uvm_dpi_regcomp, five command-line regex UVM_ERRORs and one BUILDERR UVM_FATAL. Result RUNTIME_FAIL, not smoke/application pass. Original source tree unchanged. Pinned1.2 src/dpi/uvm_svcmd_dpi.c already defines uvm_dpi_regcomp/regexec/regfree using POSIX REG_NOSUB|REG_EXTENDED; current fork umbrella includes the modern source, which lacks those exported entry points. User requested investigation. Preserve legacy strict regex semantics, allocation/free behavior and error reporting when selecting DPI work after U08 validation; do not simply alias to the modern glob-retry wrapper.


DD027/DD030 resolution (U09,19e7f5592): cached-regex exports and callback-aware
error reporting now pass focused original1.1d/1.2 checks in both editions.
Full required local gates pass. Both original releases pass smoke in
results-n2m35ki0 with unchanged source fingerprints. Other compile-time
constraint/codegen warnings and full application qualification remain open.

### DD031 — OpenTitan original1.2 macro expansion frontier

U10 replay uses explicit original1.2 root and records src hash
885ba9f74652494aa132aaaa26c43e9f210f94cdf5a8d3a87064993ec9b35dc0.
Pinned7a3ad34 debug crossbar compile exits74; first diagnostics are missing
argument list for uvm_print_aa_string_int at dv_base_env_cfg.sv112/114,
followed by parser cascades. No simulation or traffic ran.
Evidence evidence/campaign-20260908/u10/result.json and matrix-compile.log.
Record-only during U10 harness qualification; macro source/expansion and both
LRM editions require investigation before selecting any compiler change.

DD031 resolution (L15,aa356ab4d): complete pasted function-like names now expand
correctly under both editions and all required local gates pass. Fresh original1.2
OpenTitan replay removes the macro errors and cascades with unchanged UVM source
hash; compilation now exits3 at the distinct const-handle assignment frontier.

### DD032 — Mutable member assignment through a const class handle rejected

After validated L15, original1.2 OpenTitan debug crossbar compile fails three
times at dv_base_test.sv92: uvm_top.enable_print_topology = print_topology.
The diagnostic says assignment to const signal uvm_top is not allowed, although
the target is a mutable member of its referenced object. Evidence
evidence/campaign-20260908/l15/opentitan/result.json and matrix-compile.log;
source hash885ba9f74652494aa132aaaa26c43e9f210f94cdf5a8d3a87064993ec9b35dc0.
No simulation ran. Record-only during L15 closure; verify both editions and
reduce before selecting a const-handle elaboration fix.

### DD033 — Explicit package-qualified member compound assignment parser gap

L16 development positive fixture used const_handle_pkg::shared.value += 2 and
both editions rejected its statement syntax before elaboration. Imported
shared.value += 2 works and is the selected const-handle test. Preserved
evidence/l16/development.json; explicit qualified compound assignment is
record-only and not part of L16's bounded direct handle const check.

### DD034 — Existing class-member lookup/const-chain limitations

L16 independent source review confirmed the existing class-member walker can
warn and discard an unknown property write, and rejects traversal through an
intermediate const class-handle property even when the leaf is mutable.
L16 enables only direct scalar const-handle variables with existing writable
members; it does not qualify unknown-member diagnostics or const property
chains. These source-inspection findings need dedicated reducers before
implementation; no correctness claim for those paths.

DD032 resolution (L16,5ba60567f): mutable member writes through scalar const
class-handle variables pass both editions and full required gates. Original1.2
OpenTitan const-handle errors are removed. Replay runs normally with
152requests/288scoreboard items and zero UVM warnings/errors/fatals, but overall
DEBT remains because five compile-time null-substitution diagnostics persist.

### DD035 — Integral compound updates of UVM register item array members emit null

Validated L16 original1.2 OpenTitan replay reports five draw_eval_object
null-fallback warnings: uvm_reg.svh2501 (rw.value[0] &= ~wo_mask),2173
(rw.value[0] &= ((1 << m_n_bits)-1)), uvm_reg_field.svh1483,
uvm_reg_map.svh2109 (rw.value[val_idx] |= shifted data), and
uvm_reg_predictor.svh192 (reg_item.value[0] |= shifted data).
These integral selected-element operations should not take object-RHS
evaluation. Evidence evidence/campaign-20260908/l16/opentitan/{result.json,
matrix/runtime/lowrisc_dv_top_darjeeling_xbar_dbg_sim_0.1/matrix-compile.log}.
Runtime0/pass banner/zero UVM severities does not waive compile-time semantic
debt. Reduce and trace a concrete selected-element compound assignment before
selecting an implementation change; full UVM/application qualification open.

DD035 resolution: L17 d8e974913 implements integral whole-element dynamic-array
property compound updates after validated operand/receiver prerequisites. All
required gates pass; fresh original1.2 debug-crossbar smoke reports PASS with
all five substitution warnings absent. Full container/UVM qualification remains open.

### DD036 — Compound operands prematurely converted to destination width/state

During L17 focused review, byte property >>=32'd256 reaches VVP as an8bit
zero shift count; /=32'd256 also reaches division with zero divisor, whose
unknown result was masked by the two-state destination. netmisc.cc
elab_and_eval destination casting loses width/state before target lowering.
Four-state RHS into two-state compound target must retain X until the final
result conversion. Preserve l17/focus.vvp,focus.log,partial.patch. Separate
prerequisite selection required after L18; not repaired by target width logic.

L18 review note: associative compound expansion in elaborate.cc independently
reads the old get_signed flag. Existing source-inspection limitation, no
new reducer or qualification claim; outside scalar-property L18 scope.

DD036 L20 review boundary: existing associative front-end expansion builds
its binary expression at destination width before the compressed target
helper. Migrating the target's associative callers does not qualify that
separate expansion; preserve as residual width debt requiring its own reducer.
L20 claims the ordinary compressed vector paths and permanent tested shapes.

DD036 associative expression width/sign/state scope resolved by L31 at0a4e7d639
after allrequiredlocalgates. Declared element signedness and binary context now
precede extension, with final assignment conversion at store. Mixed unsigned,
wide arithmetic, self-determined shifts, state and local/property controls pass.
This does not qualify all associative compound semantics: preexisting key/receiver
reevaluation in the expansion remains a separate unqualified scope.

### DD037 — Captured class mutation notification undoes handle rebinding

L17 resumed receiver test and standalone scalar-property reducer show
notify_mutated_object_root_ sending captured root_obj back to root_net after
RHS rebinds it. Original object updates correctly but h reverts to old handle.
Evidence l17/receiver-debug and l21/red; vvp/vthread.cc19414. Selected as
L21 prerequisite at deliberate suspension boundary; no value-aggregate or
static-overlay correctness claim beyond tested contexts.

### DD038 — Legacy 1.1b/c vendor-only recording macro

At L17/L22 selection, unchanged1.1b/c macros/uvm_object_defines.svh defines
uvm_record_attribute only for QUESTA/VCS/INCA, but generic payload calls it
unconditionally. Current compiler warns undefined macro then parser recovery
asserts. Do not define a commercial-vendor macro or empty recording operation
to claim support. Recording compatibility and parser robustness require separate
assessment; original sources unchanged. Evidence results-3d_bbaiu compile logs.

DD038 design review at30b803071: parser recovery is now normal rejection
(L29), while the missing recording API remains. Independent source review rejects
an adapter that concatenates $typename with %p and calls m_set_attribute:
%p uses decimal/%g/string formatting rather than a lossless typed encoding;
the direct attribute macro has no lexical recorder argument; base uvm_recorder
bypasses the attribute macro and may record literal description text. These are
reasons not to use formatting as typed serialization, not a claim that every
%p formatting choice violates its own IEEE contract.

The original typed-value/no-artificial-width-limit recording objective remains
mandatory. Proposed native backend decomposition, to select only after L31
validation: (1) real handle ownership/lifecycle and inspectable stream/begin/
link/end/free events; (2) typed value capture preserving schema, widths, four-state
bits, real precision, strings and object identity/cycles; (3) deterministic
legacy-recorder installation and original1.1b/c integration. No macro no-op or
text-only substitute. Parent recording support stays incomplete until its full
contract is implemented and qualified.

First prerequisite should use an explicitly instantiated native-compatible
recorder before any global installation. Preserve upstream sources and actual
handle allocation. Upstream handles/m_handles are static, but file descriptors
and filenames are per recorder; native ownership must add owner/kind/lifecycle,
not reuse check_handle_kind as an ownership oracle. Avoid shared-default-filename
collisions. Failed superclass allocations return0 or-1 and must not register.
Ended-but-unfreed handles stay linkable; cross-owner links are legal. Component
begin/end can select different current recorders, unlike transaction.m_recorder;
route by original ownership. Arbitrary custom recorder integer namespaces can
collide, so native compatibility needs an explicit registration contract, never
silent adoption. A later initial block is not a deterministic default installer;
user static initializers and explicit custom recorder selection must be preserved.
Use an already-compilable original legacy release for initial lifecycle coverage;
keep1.1b/c compile reducers intact until the actual attribute API is available.
Evidence: independent recording_design_review, source anchors
uvm_recorder.svh40-41/247-365,uvm_object_globals.svh666,
uvm_component.svh2597-2760,uvm_transaction.svh667-671/776-784,
uvm_object.svh1294-1313 in original1.1b. Read-only review; no implementation
selected or changed while L31 is awaiting validation. Cross-model review skipped
in this automated continuation.

U14 concrete API review: use native lifecycle operations through the existing
context-DPI umbrella. Preserve explicit begin/end time as unsigned64, separate
from event occurrence time. Transaction-kind queries must see globally registered
transactions (including ended/unfreed) because component2649 uses that query
before linking its handle to the transaction's separately owned handle. Fiber
queries must require owner identity to invalidate stale component stream caches.
Mutation ownership stays separate. Child links are parent-to-child; caller may
own the right endpoint (transaction743/component2645), so a source-owner-only
link rule is incorrect. Preserve direction and both owners plus issuing recorder.

Native state/journal is authoritative; do not claim atomic commits across native
and superclass text logs. Validate before existing-handle mutations, reject
re-registration of retained ended handles, retain ended handles for links, and
specify live-transaction free behavior (upstream allows it). Journal write/flush
failure poisons the owner; later operations cannot report successful continuation.
If superclass allocation precedes failed native registration, explicitly undo
its membership when possible and fail the operation. New journal creation must
be exclusive, not exists-then-open, and must not collide with superclass text
output before its first open. Per-simulation cleanup must clear registry/callback
state as well as close native-owned streams. Full test must exercise actual
cross-owner begin_child_tr and component/transaction dual recording; manual links
alone would miss both API traps. These findings refine U14 before implementation;
no native source has been changed yet.

### DD039 — Bare class-scoped module variable declarations

During L22 negative-test construction, bare process::state s at module scope
parses as invalid instantiation. Independent ordinary class reducer
`class holder; typedef int state; endclass` followed by module holder::state s
fails the same way, outside the new builtin-specific lookup branch. Local
procedural declarations and typedef aliases work. Record-only general parser
gap; no grammar expansion under L22. Evidence l22/direct-module-state.sv and
ordinary-class-scoped-module.{sv,json}; bare module scope remains unqualified.

DD039 direct complete-class module declaration scope resolved by L30 at34787868e
after all required local gates. Enum identity, packed/unpacked shapes, initializers,
inherited typedefs, concrete aliases and process::state controls pass both editions.
Missing/non-type/incomplete/typeparameter prefixes remain rejected. Arbitrary
nested or parameterized class grammar and complete class qualification remain open.

### DD040 — Nested fork in a function-spawned background process

L22 release sweep now reaches UVM1.0p1 uvm_objection.svh m_forked_drop:
a function contains outer fork/join_none with nested fork/join_any in its
child begin/end. Existing diagnostic rejects inner join_any as function code.
IEEE1800-2023 13.4.4 allows task-legal statements inside function fork/join_none;
2017 wording and actual elaboration context need reducer/trace before selection.
UVM1.1a reports the same frontier. Record-only under L22; no dependent patch
on the unvalidated baseline. Evidence results-p7axbpcu/1.0p1/compile.log.

DD040 resolution: L23 58edf8034 permits blocking joins inside function-spawned
background children, retains direct-function rejection, and passes all required
gates. Original1.0p1/1.1a nested-fork errors removed; no full release pass.

### DD041 — Void function call in dedicated void-cast statement form

L23 original1.0p1/1.1a replay reaches three void'(void_function()) errors
(find_all/get_args). Independent standards review: both editions13.5 Syntax13-3
and AnnexA.6.9 allow void'(function_subroutine_call); A.8.2 does not restrict
return type. 13.4.1 forbids void functions as expressions but does not explicitly
forbid this dedicated statement form; ordinary6.24.1 cast grammar excludes void.
Candidate overly restrictive diagnostic, not established upstream-invalid source.
Permitted-statement reading is an inference needing a scoped ticket/reducer;
no relaxation or implementation during L23. Preserve calls/arguments/restrictions,
never fabricate a value or generalize to task/arbitrary-expression casts.
Evidence results-2hbuhcyt1.0p1/1.1a compile logs and original source.

### DD042 — Pre-1.1d command-line and regex DPI entry points

L24 makes original1.0p1/1.1a compile and start. Both then fail unresolved
DPI symbols dpi_get_next_arg_c/dpi_regcomp, producing four UVM command-line
regex errors (1.1a terminates BUILDERR at time0). 1.0p1 reaches smoke banner but
has errors and unresolved-functor/$cast diagnostics, so remains RUNTIME_FAIL.
Old native ABI must be inspected before reusing newer U09 cached-regex helpers;
no fabricated empty argv/regex match or DPI-disabled bypass. Record-only under
L24. Evidence results-6_pvcxya/{1.0p1,1.1a}/runtime.log.

### DD043 — Release smoke harness misses simulator runtime errors

During U11, original1.0p1 has no missing DPI and reaches its marker with zero
UVM summary counts, but still prints three unresolved-functor placeholder-net
and two failed-$cast runtime error lines already present under L24. The unchanged
smoke_passed helper checks exit/marker/UVM summaries only and incorrectly emits
SMOKE_PASS in results-zyhh1jv9. That raw row is explicitly disqualified; no clean
pass or full implementation claim. Original1.1a is a clean new smoke pass.
Record-only during U11; select a bounded harness-classification ticket at next
coordination boundary, retaining offending logs as negative regression evidence.
No compiler workaround or filtering of errors. 1.0p1 actual semantic gaps remain
separate from fixing the false-positive classifier.

DD043 resolved by U12 at1654dc4c9: fresh results-fm8uvyiv classifies1.0p1
RUNTIME_FAIL;quoted UVM_INFO remains informational. Underlying1.0p1 runtime
errors remain open. No original source or compiler changes.

### DD044 — Generic-seed callback initialization remains after L26 reducer fix

The larger `l26/forward-registry.sv` reducer has two failed casts before L26
and one after the concrete default-identity fix. The remaining failing method
belongs to a specialization keyed with unresolved forwarding from a generic
master, yet a static initialization thread calls it. Original UVM1.0p1 still
has two callback cast diagnostics in results-8054igtp and remains RUNTIME_FAIL.
This is evidence for the next bounded investigation, not yet a complete causal
explanation of both original errors. Keep unresolved generic type identities
distinct; do not equate runtime class names or suppress the cast diagnostics.
The standards say a generic class is not itself a type (both editions8.25).
Record-only during L26; preserve the original trace and failing/passing controls
before deciding the next implementation contract.

DD044 bounded direct/multilevel type-formal forwarding scope resolved by L28
at77cce610b after all required local gates. Both-edition counter/callback
reducers pass; original1.0p1 callback diagnostics are gone and its runtime
smoke passes. No runtime type-name equivalence or error suppression. Nested
type-expression/value-parameter lineage and complete class/UVM qualification
remain open; existing compile constraint/cast limitations are not resolved.

### DD045 — Foreach parser scope carrier recovery remains unqualified

L29 review found that foreach has its own untyped parser scope carriers. L29
repairs procedural begin/fork ownership; it does not redesign foreach recovery.
The nested malformed begin inside foreach rejects normally in both editions
after L29, but discarding the foreach carrier itself is a separate unqualified
robustness case. No independent failing reducer yet; record-only during L29.
Source: parse.y foreach productions; standards scope context12.7.3; do not claim
all parser recovery qualified.


### DD046 — User-requested sweep of all fallback and compile-progress paths

- **Active blocker:** DD046-TRIAGE-1 (see `.ai/ACTIVE_WORK.yaml`) as of
  2026-09-11, after the UVM smoke campaign closed (U15/U16, 15/15
  SMOKE_PASS). First triage pass:
  `evidence/campaign-20260908/dd046/triage-20260911.md`. Two candidates
  examined in `vvp/vpi_cobject.cc`. One (`vpiLineNo`) proved
  architecture-wide and was split out as DD049, not forced into a bounded
  fix. The other (a class string property's VPI write silently dropping
  when reached through a NESTED class-typed property, e.g. `obj.inner.s`)
  was root-caused, reduced (`evidence/campaign-20260908/dd046/c3.sv`), and
  resolved as **L33** (see `docs/conformance/BLOCKERS.md`). Its named
  integral follow-on was resolved as **L34** in the same pass, which also
  found and fixed a second, independent real regression (an array-indexed
  signal base silently mis-resolving) in the shared helper both L33 and
  L34 depend on -- see BLOCKERS.md L33's addendum and L34's own entry.
- **2026-09-11 comprehensive re-triage of the curated table below:** all
  twelve rows were checked against current source (nine with a concrete
  reducer, three by tracing callers/overrides where that settled the
  question without one). Eleven are now dispositioned RESOLVED or
  ALREADY-LOUD -- either fixed by earlier sessions since the table was
  written, already print a diagnostic before falling back (not DD046's
  silent-path concern), already correctly implemented for every legal
  construct tried, or (for `test_value_callback_ready`) a legitimate
  virtual-method default properly overridden wherever real filtering is
  needed. **Caveat, learned the hard way in this same session (L34's
  regression was silent at its actual source and loud only three layers
  downstream, in a generic safety net):** a nearby `cerr`/`fprintf(stderr`
  does not by itself prove a fallback is harmless, and "N reducers all
  came back correct" is *absence of a found defect*, not *proof of
  absence* -- three of the eleven rows (string/object lowering, casts,
  iteration) rest on a handful of reducers each, not exhaustive coverage,
  and are recorded here as such rather than as closed proofs. The table
  cells below record exactly what was tried for each; treat the "RESOLVED"
  label as "no defect found under this session's search," not "cannot
  contain one."
  **Lost expression typing** (`netmisc.cc`'s `elab_and_eval`, the silent
  empty-string/0.0-real/null substitution for "unresolved parameterized
  helper/container method paths that lose argument typing") was the
  twelfth row and the only one with zero loud diagnostics anywhere on its
  path. It was NOT closed by tracing a caller or a hand-written reducer --
  instead, temporary `getenv`-gated probes were added at all 7 silent
  stub sites (both `elab_and_eval` overloads), the compiler rebuilt, and
  the probe armed across two full corpora: the 357-test UVM smoke/
  regression suite (357/357 passed, 0 probe hits) and the complete
  ~5000-test legacy ivtest suite (4981/4976/0F/2NI/3EF -- the exact clean
  baseline, confirming the instrumented build introduced zero
  regressions; 0 probe hits). The instrumentation was then fully reverted
  (`git diff` on `netmisc.cc` shows no residual change) and the clean
  binary rebuilt/reinstalled. Per this pass's own calibration: an empirical
  sweep of ~5300 tests finding zero hits is stronger evidence than any
  other row's hand-picked reducers, but is still not proof the branch is
  unreachable by SOME construct neither corpus exercises -- recorded as
  such, not as a closed proof.
  **That caution proved warranted within the hour:** before moving on, a
  hand-built sanity construct (`real r; string s; r = s;`) was compiled
  with the same probe armed specifically to confirm the instrumentation
  COULD fire at all -- and it fired immediately, on the single most
  ordinary construct imaginable, not an exotic parameterized-method edge
  case. The REAL-target stub silently substitutes `0.0` for a well-typed
  STRING source with no exclusion, unlike its BOOL/LOGIC/vectorable
  sibling branch (which already excludes STRING, per R30's identical
  fix for a vector target). Root-caused against IEEE 1800-2017/2023
  6.16 (no string-to-real conversion is defined; the naive alternative
  of falling through to the existing real-cast codegen was traced and
  confirmed to also be wrong -- it would bit-reinterpret the string's
  packed bytes as an integer) and fixed as a hard error, closed as
  **L35** in `docs/conformance/BLOCKERS.md`. The lesson generalizes: an
  empirical sweep finding zero hits is only as trustworthy as the last
  time anyone confirmed the probe can fire at all -- always fire-test
  the instrumentation on a hand-built positive case before trusting its
  silence on a corpus. The `elab_expr.cc:8297` stub-callers thread
  (left open in the prior pass) was also traced to completion: 6 of 7
  callers already warn; the 7th is a deliberate silent placeholder for
  dead generic-template-body elaboration, tagged and consumed downstream
  exactly like the `in_unspecialized_param_class` case above -- correctly
  designed, not a defect. All twelve curated-table rows are now fully
  dispositioned; DD046-TRIAGE-2 is closed. Incidentally found along the
  way (both passes): `find()` on a plain (non-class-property) fixed-size
  array of non-integral elements is loudly rejected at elaboration
  (`elab_expr.cc:16554-16562`, "sorry: ... not yet implemented") -- a
  real, known feature gap, but loud, not silent, so not itself a DD046
  target; recorded here for completeness. `.ai/ACTIVE_WORK.yaml` carries
  the next-selection detail for DD046 beyond the curated table (mining
  the raw ~12,850-line fallback inventory, or shifting to the user's
  third priority phase).
- **Scope:** User explicitly expanded the request to sweep ALL fallbacks.
  Include parser/name/type resolution, elaboration, code generation, simulator,
  DPI/VPI, other compiler targets and qualification harnesses. Include silent
  constant/no-op substitutions, even without a fallback warning.
- **Evidence revision:** 3d60cb54a (compiler candidate0a4e7d639).
- **Inventory:** `evidence/campaign-20260908/fallback-tracked-candidates.tsv`
  and `.json` outside the checkout retain the file/line candidates and scanned
  file manifest. 608 tracked C/C++/header/grammar/Python/shell files scanned;
  12849 matching lines, with overlapping tags: fallback494, stub609,
  degradation2245, constant-return9652. These are search hits, NOT defect counts.
  Tests, third_party/vendor, skills, graph artifacts and untracked generated
  sources are excluded from this implementation inventory. Pinned UVM diagnostics
  remain independent application evidence.
- **Search vocabulary:** fallback/fall-back; stub/placeholder/compile-progress;
  ignored/silently/approximation/unsupported/not-enforced/noop/dummy/fabricated/
  dropped/forced-to/substitute; and literal zero/one/true/false/null/empty returns.
  Repeat against the selected revision and trace unnamed equivalent paths.

Source-confirmed candidates (reachability by legal source and exact semantic
loss still require reducers; comments and diagnostic wording are not an oracle):

| Area | Source anchors at evidence revision | Observed implementation | Qualification needed |
| --- | --- | --- | --- |
| Lost expression typing | netmisc.cc:1899 (STRING stub), 1905-1928 (REAL stub, FIXED as L35), 1845/2334/2400 (CLASS/NULL stubs), 2365 (STRING stub, 2nd overload) | **Re-triaged (2026-09-11), one real defect found and fixed as L35 after the initial "empirically unreached" disposition was challenged.** (Line numbers here are post-L35-fix current; the REAL-stub sites shifted by the fix itself, so this cell is re-anchored rather than left pointing at pre-fix locations.) These sites are the ONLY genuinely silent branches found in this whole DD046 sweep (no `cerr` anywhere on the path, unlike every sibling row). Temporary `getenv`-gated probes at all 7 stub sites (both `elab_and_eval` overloads) found zero hits across the 357-test UVM suite and the ~5000-test ivtest suite -- but per an advisor review, a probe that never fires and one that's never reached look identical, so a hand-written sanity reducer (`real r; string s; r = s;`) was built to confirm the instrumentation actually could fire before trusting that negative result. **It fired immediately** -- the REAL-target branch silently substituted `0.0` for ANY mismatched `tmp` type including a well-typed STRING, with no exclusion for the well-typed case unlike its BOOL/LOGIC/vectorable sibling branch (which already excludes STRING, per R30's fix for the identical defect shape on a vector target). Root-caused, spec-grounded (IEEE 1800-2017/2023 6.16 defines no string-to-real conversion; confirmed the naive fallthrough alternative -- `cast_to_real()`'s vec4-bitpattern-reinterpretation codegen -- is not spec-correct either), and fixed: closed as **L35** in `docs/conformance/BLOCKERS.md` (hard error, not a stub, matching the R32 class-handle/aggregate precedent). The STRING-target stubs (`1899`, `2365`) and the CLASS/NULL-target stubs (`1845`, `2334`, `2400`) were probed but never fired and were NOT touched -- they remain exactly the "empirically unreached across ~5300 tests, not proof of absence" disposition the initial pass gave, now demonstrated to need the same fire-test-first discipline before being trusted again. One further gap noted but not fixed: the second `elab_and_eval` overload's BOOL/LOGIC/vectorable branch (`netmisc.cc:2392-2398`, was `2352-2358` pre-fix) lacks the STRING exclusion its sibling (first overload, `1922-1924`) already has -- checked whether it's actually reachable: `netqueue_t : netdarray_t`, so the well-typed-aggregate hard error a few lines above already catches queue sources the same as fixed arrays, leaving only a genuinely VOID/NO_TYPE (unresolved-generic) `tmp` able to reach it -- the same "requires an actual unresolved-generic scenario" wall every other row in this sweep hit. Not sized as a promising next reducer target for that reason. | L35 (real=string) is closed. The STRING-target and CLASS/NULL-target stub branches remain open -- re-open with a fire-tested probe (confirm it CAN trigger on a hand-built construct before trusting a corpus sweep's silence) or a direct reducer. The second overload's un-excluded vectorable branch is very likely unreachable by the same aggregate-hard-error reasoning that already covers queues; not worth pursuing without new evidence. |
| Unresolved methods/functions | elab_expr.cc:8297; elaborate.cc:14061,14072 | **Re-triaged (2026-09-11), resolved.** Traced all 7 call sites of `elaborate_compile_progress_expr_method_stub_`. 6 of 7 already call `warn_compile_progress_stub_fired_` before returning the stub. The 7th (`elab_expr.cc:16388`, reached only via `should_defer_type_parameter_expr_call_`) is silent by design: it fires exclusively while elaborating a generic/unspecialized parameterized-class method body before real specialization (guarded by `is_deferred_type_parameter_expr_receiver_`, which explicitly excludes real built-ins like `randomize`/mailbox/semaphore/covergroup methods and any class with a resolvable method scope), and the resulting stub is tagged via `mark_deferred_type_parameter_stub()` so downstream consumers (e.g. the enum-assignment path at `elab_expr.cc:3334`, and `inherit_deferred_type_parameter_stub` propagation in `dup_expr.cc`/`pad_to_width.cc`/`netmisc.cc`) can recognize it as a placeholder from dead template-body elaboration that never actually executes -- the same deliberate "shape-check only" pattern already established for the `in_unspecialized_param_class` case in the Lost-expression-typing row above and the `initialize`/`m_initialize` cases in `elaborate.cc:14061`. Correctly designed, not a defect. | None -- deliberate and consistent with the codebase's established generic-body-elaboration pattern. |
| Casts | elab_expr.cc:18184 | **Re-triaged (2026-09-11).** Already loud (`cerr << ... "warning: Cast to ... not fully supported"`) before either the packed-reinterpret or non-packed unchanged-passthrough fallback. Associative-array, compatible-queue, compatible-darray, and enum casts are all handled correctly by dedicated paths well before this fallback (enum cast verified with a reducer -- `evidence/campaign-20260908/dd046/c18_cast.sv`). No reproducer attempted yet for a target type that reaches the final unchanged-passthrough branch specifically (as opposed to the packed-reinterpret branch, which is a defensible real behavior, or a path handled earlier). | Loud already; re-open only if a specific unhandled-cast-target reproducer is found that reaches the passthrough branch and produces a wrong (not just imprecise) result. |
| Constraints | parse.y:18467; original1.0p1 pick_sequence compile diagnostic | **Re-triaged (2026-09-11).** Already loud (a suppressed-after-first `cerr` warning: "pkg::func(...) with-clause is parsed but not enforced ... constraints are silently dropped"). Scoped deliberately: the grammar comment states other package-function with-clauses "retain their compile-progress diagnostic" -- only `std::randomize(...) with {...}` gets real enforcement via `set_with_constraints`. No legal SystemVerilog construct calls an arbitrary `pkg::func(...)` with a `with` clause outside the randomize family (18.7), so this branch may not be reachable by standard code at all; not attempted with a reducer this pass. | Loud already; only worth a reproducer if a real randomize-family variant (not std::randomize itself) is found routing through this branch. |
| Events and waits | elaborate.cc:19847,20322,20458,20629,20775 | **Re-triaged (2026-09-11).** All five sites already print a `cerr` warning before skipping/no-opping (unresolvable event expr, scope-as-event, class-property event expr, empty event set, unelaborable wait condition, no event sources) -- none is silent. Not attempted with a reducer; the loud diagnostics already satisfy DD046's "not silent" bar for every cited line. | Loud already at every cited site. |
| Unresolved methods/functions | elab_expr.cc:8297; elaborate.cc:14061,14072 | **Re-triaged (2026-09-11).** `elaborate.cc:14061`'s `silent_noop` cases (`rand_mode`, `copy`/`do_copy`/`print`/`record`, `initialize`/`m_initialize`) are deliberate, individually justified by in-code Phase63b/B3-B4 comments citing specific known-safe UVM dead-spec patterns (a verified-safe deferred-init race, not an oversight) -- re-litigating these without new contrary evidence isn't productive. `elaborate.cc:14072`'s general unknown-task case is loud. `elab_expr.cc:8297`'s constant-stub expression method (`elaborate_compile_progress_expr_method_stub_`) was not traced to its call site(s) this pass to confirm whether callers already warn; unexamined. | The `elab_expr.cc:8297` stub's callers are the one open thread here; everything else is either deliberate-and-justified or already loud. |
| Iteration | elaborate.cc:22119 | **Re-triaged (2026-09-11).** Already loud (`cerr << ... "warning: ... can only descend into array-like element types (compile-progress: loop body dropped)"`) before dropping the body -- a real severity concern if reachable (dropped body, not just wrong value), so worth more effort than most rows here, but three attempted legal nested-foreach shapes (assoc-of-assoc 2D, assoc-of-queue, assoc-of-assoc-of-assoc 3D) all iterate and sum correctly with no warning. No reproducer found reaching this branch. | Re-open if a specific nested-container shape is found that reaches the drop; likely needs an inner element type this pass didn't try (e.g. an unpacked struct or class-typed leaf being foreach'd one level too deep). |
| Membership | tgt-vvp/eval_vec4.c:1937 | **RESOLVED (2026-09-11 re-triage).** Current source already emits a loud `vvp.tgt error:` before the `%pushi/vec4 0` fallback, and the queue/darray/fixed-array cases immediately above it are real implementations (`%inside/arr`, `%inside/arr/o`), not stubs. Not silent; stale table entry from an earlier revision. | None -- already loud, not DD046's silent-path concern |
| Increment/decrement | tgt-vvp/eval_vec4.c:2354 (now ~2351) | **RESOLVED (2026-09-11 re-triage).** `draw_unary_inc_dec`'s switch handles `IVL_EX_SIGNAL`/`IVL_EX_SELECT`/`IVL_EX_PROPERTY` with real codegen; only a genuinely unhandled expr type reaches the `default:` fallback, which itself prints a loud `sorry:` before the read-only fallback. Reducers for the two legal lvalue shapes a table reader would suspect (queue element `q[0]++`, associative-array element `assoc["k"]++`) both compute correctly (`evidence/campaign-20260908/dd046/c14_incdec.sv`) -- neither reaches `draw_unary_inc_dec` at all, so this candidate is not reachable by the constructs it looked like it should cover. | None -- already loud where reachable, and the obvious legal reproducers don't reach it |
| Array locators | tgt-vvp/eval_object.c:2584,2622 | **RESOLVED (2026-09-11 re-triage).** Both plausible reproducers -- `find()` on a fixed-size array of non-integral elements as a plain module-level signal, and as a class property -- were tested. The plain-signal case is rejected at elaboration with a loud `sorry:` (elab_expr.cc:16554-16562) before ever reaching this codegen; the class-property case (`evidence/campaign-20260908/dd046/c16_locator_prop.sv`) elaborates via the dedicated property-materializer path the code comment describes and returns the correct result. The `%null`-emitting branch here may be reachable only through a narrower combination not yet found, or may be dead code superseded by the materializer path; neither reproducer this pass tried reaches it. | Re-open only if a specific reproducer is found; not selected as DD046's next increment |
| String/object lowering | tgt-vvp/eval_string.c:249; tgt-vvp/eval_object.c:1197,1282 | **Partially re-triaged (2026-09-11).** `eval_object.c`'s two select/null fallbacks (1197, ~1280) are already loud (`fprintf(stderr, "Warning: ...")` before the `%null`), not silent. `eval_string.c:249`'s "select on an unsupported base type -> empty string" fallback IS silent (no diagnostic) and remains genuinely open, but five attempted legal reproducers (ternary-selected string, string-concat select, bare function-call-result select, string-method-result select, queue-of-strings element select) each either hit an earlier parser/elaboration rejection (indexing a call/ternary result directly is not parseable in this grammar today) or resolved correctly through a different, already-working path (queue element char-select). No legal construct reaching this specific silent branch was found this pass; likely unreachable given current grammar restrictions on what may be select-indexed, but not proven so. | Re-open only if a specific reproducer is found for the `eval_string.c:249` branch. |
| Missing executable targets | tgt-vvp/vvp_process.c:808 | **Re-triaged (2026-09-11).** `emit_td_stub_definitions()` is a defensive bookkeeping safety net (emit an empty label for any thread-destination referenced but never defined, so a stray forward reference can't produce a dangling jump) rather than a feature-implementation fallback; not traced further this pass to find a legal construct that leaves a genuine reference unresolved. | Unclear this represents user-visible incorrect behavior; would need a concrete case where a legally-reachable TD reference has no definition. |
| Simulator/VPI | vvp/compile.cc:1148; vvp/vpi_callback.cc:217 | **Re-triaged (2026-09-11), both resolved.** `compile.cc:1148`'s placeholder-net path is already loud (`unresolved_warn_once`) and is the generic safety net that ANY malformed functor reference trips -- it is literally the mechanism whose output ("unresolved functor stub"/"created placeholder net") was the observed symptom of the real L34 regression this session found and fixed; it did its job correctly. `vpi_callback.cc:217`'s `test_value_callback_ready()` "stub" is a legitimate virtual-method default (always-ready is correct for a plain full-value-change callback) properly overridden by `value_part_callback`/`array_word_part_callback`/`runtime_array_word_value_callback` wherever real bit/word-range filtering is actually needed -- traced all overrides and call sites; this is correct OOP design, not a defect. | None -- both already resolved (one already loud+working-as-intended, one already correctly designed). |
| Qualification fallback | .github/uvm_test.sh:139 | Already understood at DD046's original writing: this row's own "Qualification needed" column already states the correct handling (keep real-DPI/no-DPI evidence separate). Not re-examined this pass; harness-flavored, not a compiler-semantics candidate. | Low priority; the existing disposition already looks correct. |

- **Triage:** OPEN, semantic classification pending. Ordinary allocation
  fallbacks, generated DPI bridge stubs, valid empty-container results and
  error-recovery paths are not automatically defects. Inspect the surrounding
  control flow and terminal diagnostic status. Source-confirmed substitution
  does not yet prove a legal reproducer reaches it.
- **Completion rule:** Every candidate must be classified as valid behavior,
  unreachable/superseded with evidence, explicit unsupported/qualification gap,
  or a reproduced semantic defect. All legal behavior-changing fallbacks need
  standards-grounded implementation and permanent regressions; warning removal,
  an unsupported error, or a smoke pass alone cannot close that obligation.
  Keyword coverage is not semantic exhaustiveness; review default branches,
  early returns, ignored statuses and synthesized values by requirement cluster.


DD046 first reachability check: a fixed-size real array `find with (item > 1.5)`
is rejected with compile exit1 in both2017/2023 before code generation:
"find() on fixed-size arrays of non-integral elements is not yet implemented."
The fallback in eval_object.c is therefore not reached by this reducer. Record
this case as an explicit unsupported legal feature, not observed fabricated
runtime results. Evidence: `evidence/campaign-20260908/fallback-reducers/`
`fixed-real-find.sv` and `fixed-real-find.json`. Other routes remain unqualified.


DD038 prerequisite U14 locally validated at729edce3c with test/CI79885f484:
explicit original1.1d lifecycle recorder, native owner/handle registry, retained
exclusive file descriptors, cross-owner links and allocation rollback are real
and regression-tested. Full local gates pass (BLOCKERS U14). Typed attribute
capture and deterministic default installation remain mandatory and OPEN;
original1.1b/c still fail the missing macro. No parent completion claim.


### DD047 — String literal with a high-bit byte fails to load as a vector operand

- **Active blocker:** L32; record-only.
- **Observation:** `x = "\301B";` into `reg [15:0]` and `y = "\377";` into
  `reg [7:0]` compile with exit 0 in both 2017 and 2023, but vvp refuses to load:
  `numeric operand out of range` (`%pushi/vec4 18446744073709535554, 0, 16`).
  Expected: x=c142, y=ff.
- **File/function:** `tgt-vvp/eval_vec4.c` `draw_string_vec4`:
  `tmp |= (unsigned long)*p` on a plain `char`, which is signed on this ARM64 host,
  so bytes of 0x80 and above sign-extend.
- **Possible clause:** IEEE 1800-2017/2023 5.9 (literal operands are unsigned
  integer constants of 8-bit values).
- **Evidence:** `evidence/campaign-20260908/l32/dd-hibit-assign.v` and `.log`.
  Not introduced by L32 (`ab54351c3` touches only `vvp/vpi_const.cc` among
  implementation files). Upstream master still has the same loop.
- **Triage:** OPEN; reproduced; candidate for the next selection.

L32 note: upstream master `vvp/vpi_const.cc` still has the pre-L32 literal
`vpiVectorVal` loop. Upstream `ivtest/ivltests/swrite.v` still has the endian
probe that depended on it. An upstream report is a separate, unfiled action.


### DD048 — __vpiVThrStrStack has no vpiVectorVal path; vpiSize unit differs from __vpiStringConst

- **Active blocker:** U15; record-only (worked around, not fixed).
- **Observation:** A systf string argument that is not a bare literal --
  a `string` variable, an enum `.name()` result, a function-call result, or a
  runtime concatenation -- is represented by `__vpiVThrStrStack`
  (vvp/vpi_vthr_vector.cc), which rejects `vpiVectorVal`
  (`vvp error: get 9 not supported by vpiConstant (String)`, unconditional
  stderr, format returns `vpiSuppressVal`) even though `vpiType`/`vpiConstType`
  report `vpiConstant`/`vpiStringConst` identically to a real literal (a
  `__vpiStringConst`, vvp/vpi_const.cc, L32-fixed). The two classes also
  report `vpiSize` in different units for the same property code:
  `__vpiStringConst` returns bits (`value_len_*8`); `__vpiVThrStrStack`
  returns characters (`val.size()`). A 5-character enum `.name()` reports
  `vpiSize==5`, not 40.
- **File/function:** `vvp/vpi_vthr_vector.cc` `__vpiVThrStrStack::vpi_get_value`
  (no `vpiVectorVal` case) and `__vpiVThrStrStack::vpi_get` (`vpiSize`).
- **Consequence for U15:** `$ivl_uvm_record_attribute`'s string encoder
  (uvm_dpi/uvm_recording.cc) cannot use `vpiType`/`vpiConstType` to select a
  byte-exact read path, since both classes present identically at that level.
  It instead reads `vpiStringVal` first and compares the result's length
  against `vpiSize` under both possible unit conventions (`*8` and as-is);
  only a mismatch (reachable in practice only via a true literal whose value
  contains an embedded NUL, which `__vpiStringConst`'s own `vpiStringVal`
  branch alters rather than truncates) triggers a `vpiVectorVal` retry. This
  keeps the common non-literal path silent and correct and confines the
  byte-exact/embedded-NUL path to where it is actually reachable, but it does
  not give `__vpiVThrStrStack` a lossless path: a genuinely NUL-containing
  runtime string expression (e.g. a literal fragment concatenated into a
  variable at runtime) cannot be captured exactly and is reported as a loud
  failure rather than silently truncated.
- **Evidence:** `evidence/campaign-20260908/u15/se2.sv`/`se2.c` (direct
  probe), `expression-string-args-20260911.log` (pre-fix failure),
  `expression-string-args-fixed-20260911.log` (post-fix). Permanent
  regression: `tests/uvm_releases/recording_attribute.sv` `string_enum_name`/
  `string_func_result`/`string_concat` cases plus the harness's
  `"vvp error: get" not in output` assertion.
- **Triage:** OPEN; reproduced; candidate for a future selection. Giving
  `__vpiVThrStrStack` a `vpiVectorVal` path (and reconciling the `vpiSize`
  unit inconsistency generally, not only for this one caller) is a separate,
  non-trivial VPI runtime change, out of U15's scope.


### DD049 — vpiLineNo/vpiFile never captured for signals, part-selects or class variables

- **Active blocker:** DD046 triage; record-only.
- **Observation:** `vpi_get(vpiLineNo, handle)` returns a hardcoded `0` for
  every ordinary signal/net/reg (`__vpiSignal`, `vvp/vpi_signal.cc:552`),
  every part/bit select (`__vpiPV`, `vvp/vpi_signal.cc:1415`), and every
  class variable (`__vpiCobjectVar`, `vvp/vpi_cobject.cc:201`) -- all three
  sites carry the identical `// Not implemented for now!` comment. `struct
  __vpiSignal` (vvp/vpi_priv.h) has no file/line storage field at all: the
  value was never captured, not merely left unwired to an existing field.
- **Possible clause:** IEEE1800-2017 37.3.3: "Most objects have... vpiLineNo
  [and] vpiFile... applicable to every object that corresponds to some
  object within the source code," with an explicit exception list that does
  not include signals, part-selects, or class variables -- so this is
  normatively required for these kinds, not optional.
- **Reachability:** trivial; any `vpi_get(vpiLineNo, ...)` on an affected
  handle observes it.
- **Scope:** architecture-wide, not a bounded single-function fix. A correct
  fix needs new file/line plumbing from elaboration through netlist
  compilation into vvp bytecode/VPI object creation, for every affected
  object kind (not fully enumerated -- these three classes were the ones
  examined; other classes were not checked for the same pattern).
- **Evidence:** `evidence/campaign-20260908/dd046/triage-20260911.md`
  (Candidate 1).
- **Triage:** OPEN; reproduced; too large for one bounded DD046 increment.
  A future selection should scope it explicitly as its own multi-part
  feature (which object kinds, what elaboration-to-vvp plumbing) rather than
  a single reducer-sized fix.
